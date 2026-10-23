CREATE TABLE IF NOT EXISTS audit.function_calls (
    call_id        serial PRIMARY KEY,
    call_time      timestamp DEFAULT now() NOT NULL,
    function_name  text NOT NULL,
    caller_role    text NOT NULL,
    input_params   text,
    success        boolean NOT NULL,
    error_message  text
);

COMMENT ON TABLE audit.function_calls IS 'Журнал вызовов SECURITY DEFINER-функций';
GRANT SELECT ON audit.function_calls TO auditor;

CREATE OR REPLACE FUNCTION audit.log_action() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'audit', 'public'
    AS $$
DECLARE
    v_action action_type_enum;
    v_staff_id INT;
BEGIN
    BEGIN
        v_staff_id := current_setting('app.current_staff_id', true)::INT;
    EXCEPTION WHEN invalid_text_representation THEN
        v_staff_id := NULL;
    END;
    IF v_staff_id IS NULL THEN
        RETURN NULL;  -- не пишем в аудит, если сотрудник не установлен
    END IF;
    IF TG_OP = 'INSERT' THEN v_action := 'CREATE';
    ELSIF TG_OP = 'UPDATE' THEN v_action := 'UPDATE';
    ELSIF TG_OP = 'DELETE' THEN v_action := 'DELETE';
    ELSE v_action := 'OTHER';
    END IF;
    INSERT INTO audit.audit_log (staff_id, action_time, action_type, action_description, success)
    VALUES (v_staff_id, now(), v_action, format('Таблица: %s, действие: %s', TG_TABLE_NAME, TG_OP), TRUE);
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION app.create_order(
    p_client_id INT,
    p_payinfo_id INT,
    p_delivery_address VARCHAR,
    p_items JSON
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
    new_order_id INT;
    item RECORD;
    product_price NUMERIC;
    current_stock INT;
    subtotal NUMERIC;
    total_sum NUMERIC := 0;
    client_exists BOOLEAN;
    payinfo_exists BOOLEAN;
    err_msg TEXT;
    log_params TEXT;
BEGIN
    log_params := format('client_id=%s, payinfo_id=%s, items=%s', p_client_id, p_payinfo_id, p_items);

    SELECT EXISTS(SELECT 1 FROM app.clients WHERE client_id = p_client_id) INTO client_exists;
    IF NOT client_exists THEN
        err_msg := format('Клиент с id=%s не найден', p_client_id);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, FALSE, err_msg);
        RETURN NULL;
    END IF;

    SELECT EXISTS(SELECT 1 FROM app.payment_information WHERE payinfo_id = p_payinfo_id) INTO payinfo_exists;
    IF NOT payinfo_exists THEN
        err_msg := format('Платёжная информация с id=%s не найдена', p_payinfo_id);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, FALSE, err_msg);
        RETURN NULL;
    END IF;

    INSERT INTO app.orders(client_id, payinfo_id, order_date, total_amount, delivery_address)
    VALUES (p_client_id, p_payinfo_id, CURRENT_DATE, 0, p_delivery_address)
    RETURNING order_id INTO new_order_id;

    FOR item IN SELECT * FROM json_to_recordset(p_items) AS (product_id INT, quantity INT)
    LOOP
        SELECT price, stock_quantity INTO product_price, current_stock
        FROM app.products WHERE product_id = item.product_id;

        IF NOT FOUND THEN
            err_msg := format('Товар с id=%s не найден', item.product_id);
            INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
            VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, FALSE, err_msg);
            RETURN NULL;
        END IF;

        IF item.quantity < 1 THEN
            err_msg := format('Количество для товара %s должно быть >= 1', item.product_id);
            INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
            VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, FALSE, err_msg);
            RETURN NULL;
        END IF;

        IF item.quantity > current_stock THEN
            err_msg := format('Недостаточно товара на складе для продукта %s', item.product_id);
            INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
            VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, FALSE, err_msg);
            RETURN NULL;
        END IF;

        subtotal := product_price * item.quantity;
        total_sum := total_sum + subtotal;

        INSERT INTO app.order_items(order_id, product_id) VALUES (new_order_id, item.product_id);
        UPDATE app.products SET stock_quantity = stock_quantity - item.quantity WHERE product_id = item.product_id;
    END LOOP;

    UPDATE app.orders SET total_amount = total_sum WHERE order_id = new_order_id;

    INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
    VALUES ('create_order', COALESCE(current_setting('role', true), current_user), log_params, TRUE, NULL);

    RAISE NOTICE 'Заказ % успешно создан, сумма = %', new_order_id, total_sum;
    RETURN new_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION app.cancel_order(p_order_id INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
    current_status order_status;
    item RECORD;
    err_msg TEXT;
BEGIN
    SELECT status INTO current_status FROM app.orders WHERE order_id = p_order_id;
    IF NOT FOUND THEN
        err_msg := format('Заказ с id=%s не найден', p_order_id);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('cancel_order', COALESCE(current_setting('role', true), current_user), format('order_id=%s', p_order_id), FALSE, err_msg);
        RETURN;
    END IF;

    IF current_status NOT IN ('Создан', 'Оплачен') THEN
        err_msg := format('Невозможно отменить заказ со статусом "%s"', current_status);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('cancel_order', COALESCE(current_setting('role', true), current_user), format('order_id=%s', p_order_id), FALSE, err_msg);
        RETURN;
    END IF;

    FOR item IN SELECT product_id, COUNT(*) AS qty FROM app.order_items WHERE order_id = p_order_id GROUP BY product_id
    LOOP
        UPDATE app.products SET stock_quantity = stock_quantity + item.qty WHERE product_id = item.product_id;
    END LOOP;

    UPDATE app.orders SET status = 'Отменен' WHERE order_id = p_order_id;

    INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
    VALUES ('cancel_order', COALESCE(current_setting('role', true), current_user), format('order_id=%s', p_order_id), TRUE, NULL);

    RAISE NOTICE 'Заказ % успешно отменён', p_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION app.update_order_status(p_order_id INT, p_new_status order_status)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'app', 'public'
AS $$
DECLARE
    current_status order_status;
    err_msg TEXT;
BEGIN
    SELECT status INTO current_status FROM app.orders WHERE order_id = p_order_id;
    IF NOT FOUND THEN
        err_msg := format('Заказ с id=%s не найден', p_order_id);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('update_order_status', COALESCE(current_setting('role', true), current_user), format('order_id=%s, new_status=%s', p_order_id, p_new_status), FALSE, err_msg);
        RETURN;
    END IF;

    IF current_status = 'Отменен' AND p_new_status != 'Отменен' THEN
        err_msg := format('Нельзя изменить статус отменённого заказа на "%s"', p_new_status);
        INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
        VALUES ('update_order_status', COALESCE(current_setting('role', true), current_user), format('order_id=%s, new_status=%s', p_order_id, p_new_status), FALSE, err_msg);
        RETURN;
    END IF;

    UPDATE app.orders SET status = p_new_status WHERE order_id = p_order_id;

    INSERT INTO audit.function_calls(function_name, caller_role, input_params, success, error_message)
    VALUES ('update_order_status', COALESCE(current_setting('role', true), current_user), format('order_id=%s, new_status=%s', p_order_id, p_new_status), TRUE, NULL);

    RAISE NOTICE 'Статус заказа % изменён на %', p_order_id, p_new_status;
END;

REVOKE ALL ON FUNCTION app.create_order(INT, INT, VARCHAR, JSON) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.cancel_order(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION app.update_order_status(INT, order_status) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION app.create_order(INT, INT, VARCHAR, JSON) TO app_reader, app_writer;
GRANT EXECUTE ON FUNCTION app.cancel_order(INT) TO app_reader, app_writer;
GRANT EXECUTE ON FUNCTION app.update_order_status(INT, order_status) TO app_writer, app_owner;

CREATE OR REPLACE FUNCTION app.check_total_amount_trigger() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.total_amount < 0 THEN
        RAISE EXCEPTION 'Сумма заказа не может быть отрицательной (%.2f)', NEW.total_amount;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_total_amount ON app.orders;
CREATE TRIGGER trg_check_total_amount
BEFORE INSERT OR UPDATE ON app.orders
FOR EACH ROW EXECUTE FUNCTION app.check_total_amount_trigger();

ALTER TABLE app.orders DISABLE TRIGGER trg_check_total_amount;
