\set ON_ERROR_STOP off

SET ROLE app_reader;
DO $$
DECLARE
    order_id INT;
BEGIN
    RAISE NOTICE '=== Тест 1: app_reader -> create_order (валидные данные) ===';
    order_id := app.create_order(1, 101, 'Тестовый адрес', '[{"product_id": 1, "quantity": 2}]'::JSON);
    IF order_id IS NOT NULL THEN
        RAISE NOTICE 'Успешно создан заказ №%', order_id;
    ELSE
        RAISE NOTICE 'Ошибка: заказ не создан';
    END IF;
END $$;
RESET ROLE;

SET ROLE app_reader;
DO $$
DECLARE
    order_id INT;
BEGIN
    RAISE NOTICE '=== Тест 2: app_reader -> create_order (невалидный клиент) ===';
    order_id := app.create_order(-1, 101, 'Адрес', '[{"product_id": 1, "quantity": 1}]'::JSON);
    IF order_id IS NULL THEN
        RAISE NOTICE 'Ожидаемый отказ: заказ не создан';
    ELSE
        RAISE NOTICE 'ОШИБКА: заказ создан';
    END IF;
END $$;
RESET ROLE;

SET ROLE app_reader;
DO $$
DECLARE
    order_id INT;
BEGIN
    RAISE NOTICE '=== Тест 3: app_reader -> cancel_order (валидный заказ) ===';
    order_id := app.create_order(1, 101, 'Для отмены', '[{"product_id": 2, "quantity": 1}]'::JSON);
    IF order_id IS NOT NULL THEN
        PERFORM app.cancel_order(order_id);
        RAISE NOTICE 'Заказ №% успешно отменён', order_id;
    ELSE
        RAISE NOTICE 'Ошибка: заказ не создан';
    END IF;
END $$;
RESET ROLE;

SET ROLE app_reader;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 4: app_reader -> cancel_order (несуществующий заказ) ===';
    PERFORM app.cancel_order(-999);
    RAISE NOTICE 'Ожидаемый отказ: заказ не отменён';
END $$;
RESET ROLE;

SET ROLE app_reader;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 5: app_reader -> прямой INSERT в app.orders ===';
    INSERT INTO app.orders(client_id, payinfo_id, order_date, total_amount, delivery_address)
    VALUES (1, 101, CURRENT_DATE, 100, 'Адрес');
    RAISE NOTICE 'ОШИБКА: прямой INSERT разрешён';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Ожидаемый отказ: нет прав на INSERT';
END $$;
RESET ROLE;

SET ROLE dml_admin;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 6: dml_admin -> INSERT в audit.audit_log ===';
    INSERT INTO audit.audit_log(staff_id, action_time, action_type, action_description, success)
    VALUES (1, now(), 'CREATE', 'test', true);
    RAISE NOTICE 'ОШИБКА: INSERT в audit разрешён';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Ожидаемый отказ: нет прав на INSERT в audit';
END $$;
RESET ROLE;

SET ROLE ddl_admin;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 7: ddl_admin -> CREATE TABLE ===';
    EXECUTE 'CREATE TABLE app.test_ddl_lab2(id INT)';
    RAISE NOTICE 'Таблица создана успешно';
    EXECUTE 'DROP TABLE app.test_ddl_lab2';
    RAISE NOTICE 'Таблица удалена';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка: %', SQLERRM;
END $$;
RESET ROLE;

SET ROLE auditor;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 8: auditor -> чтение audit.function_calls ===';
    PERFORM * FROM audit.function_calls LIMIT 1;
    RAISE NOTICE 'Чтение разрешено';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'ОШИБКА: нет прав на чтение';
END $$;
RESET ROLE;

SET ROLE app_reader;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 9: app_reader -> update_order_status (должен быть запрещён) ===';
    PERFORM app.update_order_status(1, 'Оплачен');
    RAISE NOTICE 'ОШИБКА: вызов разрешён';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Ожидаемый отказ: нет прав на выполнение функции';
END $$;
RESET ROLE;

SET ROLE app_writer;
DO $$
BEGIN
    RAISE NOTICE '=== Тест 10: app_writer -> update_order_status ===';
    PERFORM app.update_order_status(1, 'Оплачен');
    RAISE NOTICE 'Успешно изменён статус';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка: %', SQLERRM;
END $$;
RESET ROLE;

DO $$
BEGIN
    RAISE NOTICE '=== Журнал вызовов функций (последние 10) ===';
END $$;
SELECT call_time, function_name, caller_role, success, error_message
FROM audit.function_calls
ORDER BY call_time DESC
LIMIT 10;
