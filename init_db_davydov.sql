SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA app;
ALTER SCHEMA app OWNER TO postgres;

CREATE SCHEMA audit;
ALTER SCHEMA audit OWNER TO postgres;

CREATE SCHEMA ref;
ALTER SCHEMA ref OWNER TO postgres;

CREATE SCHEMA stg;
ALTER SCHEMA stg OWNER TO postgres;

CREATE EXTENSION IF NOT EXISTS pgaudit WITH SCHEMA public;
COMMENT ON EXTENSION pgaudit IS 'provides auditing functionality';

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

CREATE TYPE public.action_type_enum AS ENUM ('CREATE', 'UPDATE', 'DELETE', 'OTHER');
ALTER TYPE public.action_type_enum OWNER TO postgres;

CREATE TYPE public.clients_status AS ENUM ('Активен', 'Неактивен', 'Заблокирован');
ALTER TYPE public.clients_status OWNER TO postgres;

CREATE TYPE public.order_status AS ENUM ('Создан', 'Оплачен', 'В обработке', 'Отправлен', 'Доставлен', 'Отменен');
ALTER TYPE public.order_status OWNER TO postgres;

CREATE TYPE public.staff_role AS ENUM ('Менеджер', 'Администратор', 'Бухгалтер', 'Складской');
ALTER TYPE public.staff_role OWNER TO postgres;

CREATE FUNCTION audit.log_action() RETURNS trigger
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
        v_staff_id := -1;
    END;
    IF v_staff_id IS NULL THEN
        v_staff_id := -1;
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
ALTER FUNCTION audit.log_action() OWNER TO postgres;

CREATE FUNCTION audit.login_audit() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO audit.login_log(username, client_ip)
    VALUES (session_user, inet_client_addr());
END;
$$;
ALTER FUNCTION audit.login_audit() OWNER TO postgres;

CREATE TABLE app.clients (
    client_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    middle_name character varying(50),
    email character varying(255) NOT NULL,
    phone_number character varying(20) NOT NULL,
    password_hash text NOT NULL,
    registration_date timestamp without time zone DEFAULT now() NOT NULL,
    date_of_birth date NOT NULL,
    status public.clients_status DEFAULT 'Неактивен'::public.clients_status NOT NULL,
    CONSTRAINT clients_phone_number_check CHECK (((phone_number)::text ~ '^[0-9]{11}$'::text))
);
ALTER TABLE app.clients OWNER TO postgres;
COMMENT ON TABLE app.clients IS 'Таблица с данными о клиентах';

CREATE SEQUENCE app.clients_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE app.clients_id_seq OWNER TO postgres;
ALTER SEQUENCE app.clients_id_seq OWNED BY app.clients.client_id;

CREATE TABLE app.order_items (
    order_id integer NOT NULL,
    product_id integer NOT NULL
);
ALTER TABLE app.order_items OWNER TO postgres;
COMMENT ON TABLE app.order_items IS 'Таблица M:N, чтобы один заказ мог хранить много товаров';

CREATE TABLE app.orders (
    order_id integer NOT NULL,
    client_id integer NOT NULL,
    payinfo_id integer NOT NULL,
    order_date date NOT NULL,
    status public.order_status DEFAULT 'Создан'::public.order_status NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    delivery_address character varying(100) NOT NULL,
    date_of_creation timestamp without time zone DEFAULT now(),
    CONSTRAINT chk_total_amount_positive CHECK ((total_amount >= (0)::numeric))
);
ALTER TABLE app.orders OWNER TO postgres;
COMMENT ON TABLE app.orders IS 'Таблица с заказами';

CREATE SEQUENCE app.orders_order_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE app.orders_order_id_seq OWNER TO postgres;
ALTER SEQUENCE app.orders_order_id_seq OWNED BY app.orders.order_id;

CREATE TABLE app.payment_information (
    payinfo_id integer NOT NULL,
    client_id integer NOT NULL,
    method_id integer NOT NULL,
    card_number character varying(255),
    card_cvv character varying(255),
    card_expiry date
);
ALTER TABLE app.payment_information OWNER TO postgres;
COMMENT ON TABLE app.payment_information IS 'Таблица с платежными данными клиентов';

CREATE SEQUENCE app.payment_information_info_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE app.payment_information_info_id_seq OWNER TO postgres;
ALTER SEQUENCE app.payment_information_info_id_seq OWNED BY app.payment_information.payinfo_id;

CREATE TABLE app.products (
    product_id integer NOT NULL,
    category_id integer NOT NULL,
    product_name character varying(100) NOT NULL,
    price numeric(10,2) NOT NULL,
    stock_quantity integer NOT NULL,
    article character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_stock_quantity_check CHECK ((stock_quantity >= 0))
);
ALTER TABLE app.products OWNER TO postgres;
COMMENT ON TABLE app.products IS 'Таблица, которая хранит в себе различные товары';

CREATE SEQUENCE app.products_product_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE app.products_product_id_seq OWNER TO postgres;
ALTER SEQUENCE app.products_product_id_seq OWNED BY app.products.product_id;

CREATE TABLE app.staff (
    staff_id integer NOT NULL,
    username character varying(20) NOT NULL,
    password_hash text NOT NULL,
    email character varying(255) NOT NULL,
    role public.staff_role NOT NULL,
    full_name character varying(50) NOT NULL,
    date_of_creation timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true NOT NULL
);
ALTER TABLE app.staff OWNER TO postgres;
COMMENT ON TABLE app.staff IS 'Таблица с данными о сотрудниках';

CREATE SEQUENCE app.staff_staff_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE app.staff_staff_id_seq OWNER TO postgres;
ALTER SEQUENCE app.staff_staff_id_seq OWNED BY app.staff.staff_id;

CREATE TABLE audit.audit_log (
    audit_log_id integer NOT NULL,
    staff_id integer NOT NULL,
    action_time timestamp without time zone DEFAULT now() NOT NULL,
    action_type public.action_type_enum NOT NULL,
    action_description text,
    success boolean NOT NULL
);
ALTER TABLE audit.audit_log OWNER TO postgres;
COMMENT ON TABLE audit.audit_log IS 'Таблица аудита';

CREATE SEQUENCE audit.audit_log_audit_log_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE audit.audit_log_audit_log_id_seq OWNER TO postgres;
ALTER SEQUENCE audit.audit_log_audit_log_id_seq OWNED BY audit.audit_log.audit_log_id;

CREATE TABLE audit.login_log (
    login_time timestamp without time zone DEFAULT now(),
    username text,
    client_ip inet
);
ALTER TABLE audit.login_log OWNER TO postgres;

CREATE TABLE ref.payment_method (
    method_id integer NOT NULL,
    method_name character varying(50) NOT NULL,
    description text
);
ALTER TABLE ref.payment_method OWNER TO postgres;
COMMENT ON TABLE ref.payment_method IS 'Таблица со способами оплаты';

CREATE SEQUENCE ref.payment_method_method_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE ref.payment_method_method_id_seq OWNER TO postgres;
ALTER SEQUENCE ref.payment_method_method_id_seq OWNED BY ref.payment_method.method_id;

CREATE TABLE ref.product_category (
    category_id integer NOT NULL,
    category_name character varying(50) NOT NULL,
    description text
);
ALTER TABLE ref.product_category OWNER TO postgres;
COMMENT ON TABLE ref.product_category IS 'Таблица с категориями товаров';

CREATE SEQUENCE ref.product_category_category_id_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE ref.product_category_category_id_seq OWNER TO postgres;
ALTER SEQUENCE ref.product_category_category_id_seq OWNED BY ref.product_category.category_id;

ALTER TABLE ONLY app.clients ALTER COLUMN client_id SET DEFAULT nextval('app.clients_id_seq'::regclass);
ALTER TABLE ONLY app.orders ALTER COLUMN order_id SET DEFAULT nextval('app.orders_order_id_seq'::regclass);
ALTER TABLE ONLY app.payment_information ALTER COLUMN payinfo_id SET DEFAULT nextval('app.payment_information_info_id_seq'::regclass);
ALTER TABLE ONLY app.products ALTER COLUMN product_id SET DEFAULT nextval('app.products_product_id_seq'::regclass);
ALTER TABLE ONLY app.staff ALTER COLUMN staff_id SET DEFAULT nextval('app.staff_staff_id_seq'::regclass);
ALTER TABLE ONLY audit.audit_log ALTER COLUMN audit_log_id SET DEFAULT nextval('audit.audit_log_audit_log_id_seq'::regclass);
ALTER TABLE ONLY ref.payment_method ALTER COLUMN method_id SET DEFAULT nextval('ref.payment_method_method_id_seq'::regclass);
ALTER TABLE ONLY ref.product_category ALTER COLUMN category_id SET DEFAULT nextval('ref.product_category_category_id_seq'::regclass);


INSERT INTO app.clients (client_id, first_name, last_name, middle_name, email, phone_number, password_hash, registration_date, date_of_birth, status) VALUES
(1, 'Александр', 'Смирнов', 'Викторович', 'alex.smirnov@mail.ru', '79161234501', '$2a$06$Hk.GvajSejsOldg4aaDBu.OmGPiyYLY0IOSIaGZ5POpvuok/sbjbm', '2025-01-15 10:20:00', '1991-04-12', 'Активен'),
(2, 'Дмитрий', 'Кузнецов', 'Андреевич', 'dmitry.kuznetsov@yandex.ru', '79162345602', '$2a$06$WebTDj4xhNEMsRo6fUANN.eVlumcKybzUP9YkfNzkJBcZtDgr/132', '2025-02-18 14:35:00', '1987-08-23', 'Неактивен'),
(3, 'Елена', 'Попова', 'Сергеевна', 'elena.popova@gmail.com', '79163456703', '$2a$06$osnSEzX8wXqLMkKDrKzRauUt7dQKJcu.zTC/YhfqbA88T9cpKyibS', '2025-03-05 09:50:00', '1994-11-30', 'Активен'),
(4, 'Ольга', 'Васильева', 'Николаевна', 'olga.vasilyeva@mail.ru', '79164567804', '$2a$06$pR3aP/EiiHOOUGMgGq5E/uF/4YPHbP8ulvkNmyxYzlJwwOvb3pSyO', '2025-04-22 16:10:00', '1990-02-14', 'Активен'),
(5, 'Иван', 'Петров', 'Максимович', 'ivan.petrov@bk.ru', '79165678905', '$2a$06$W7KbcfjSfu8hP6GZnANjCeqv6r.mpAgM78TyIHbIb5M/btMwO3BAa', '2025-05-11 11:25:00', '1986-06-08', 'Заблокирован'),
(6, 'Наталья', 'Соколова', 'Владимировна', 'natalia.sokolova@yandex.ru', '79166789006', '$2a$06$Q8i6YJHQjPfPxDmuSScXMOfsy.WOvEZjN.8DEWN1jYWwLPmUxkrIe', '2025-06-27 13:45:00', '1997-09-19', 'Активен'),
(7, 'Павел', 'Морозов', 'Денисович', 'pavel.morozov@mail.ru', '79167890107', '$2a$06$W8ENqYrZOk2IWPYjQfwtvu4k3nOndze59Bm30DGuBUV.cT0GyqUDu', '2025-07-14 18:05:00', '1992-01-25', 'Неактивен'),
(8, 'Анна', 'Новикова', 'Алексеевна', 'anna.novikova@gmail.com', '79168901208', '$2a$06$fijZhbsO/hp6fS6wW2.2BO5D68aXeJtRUzdr3QgXFauzHtiL7l97y', '2025-08-09 08:40:00', '1995-05-03', 'Активен'),
(9, 'Роман', 'Фёдоров', 'Игоревич', 'roman.fedorov@bk.ru', '79169012309', '$2a$06$Jfjgq78o56VM/3bIhhkbm.ipQSuzoeQp.jRH.iXbb0pISuhimwh.6', '2025-09-21 15:15:00', '1988-12-17', 'Активен'),
(10, 'Татьяна', 'Егорова', 'Петровна', 'tatiana.egorova@yandex.ru', '79170123410', '$2a$06$gb6eLxCWAxdxhIS.qc93quQMnNIY2ktEU3FHLJmZln0wYwi11.uSG', '2025-10-08 12:30:00', '1993-07-21', 'Неактивен');

INSERT INTO app.staff (staff_id, username, password_hash, email, role, full_name, date_of_creation, is_active) VALUES
(1, 'morozov_m', '$2a$06$YFfHkZO3A8JGRh8yygiFaucT1AvFhn0jr/55PjXJLJ.vDJOUEyPbW', 'morozov@shop.ru', 'Менеджер', 'Морозов Андрей Петрович', '2025-01-05 09:00:00', true),
(2, 'kuznetsova_a', '$2a$06$vkfZ951mB5fcxCGiROjPze6f4WVBOef9pr/wmv/4zx/OUhPOvhHDq', 'kuznetsova@shop.ru', 'Администратор', 'Кузнецова Анна Сергеевна', '2025-01-06 09:30:00', true),
(3, 'sokolov_d', '$2a$06$mWCdT7b.8N9Os6KPbj1kvuCKwOAmoB5zkAGOgarYb3ZAACWELthUO', 'sokolov@shop.ru', 'Бухгалтер', 'Соколов Дмитрий Иванович', '2025-02-02 10:00:00', true),
(4, 'volkova_e', '$2a$06$v9ZSrHpjG6bKe.0zUdMvc.VaxAogZiFkr5EVhkp6BTqJOu/YXdUbG', 'volkova@shop.ru', 'Складской', 'Волкова Елена Николаевна', '2025-02-10 11:15:00', true),
(5, 'pavlov_n', '$2a$06$hH8daHZLo2oIW83.HYw/Gu/BnurUHBZ5W83BfVLdEI7iGTwhrOXfG', 'pavlov@shop.ru', 'Менеджер', 'Павлов Никита Олегович', '2025-03-12 12:00:00', true),
(6, 'zaitseva_t', '$2a$06$0Qn7Akw0blfo/TEi08u.LujWoAuP4SsnVR0vHkE86UZG2lmF0XhZy', 'zaitseva@shop.ru', 'Складской', 'Зайцева Татьяна Сергеевна', '2025-03-20 13:10:00', true),
(7, 'lebedev_i', '$2a$06$05kxYRCWqudIEfFyjDjj7.1Do7UfTLJYTDZsJad2wTMUno6/XOtqa', 'lebedev@shop.ru', 'Бухгалтер', 'Лебедев Игорь Владимирович', '2025-04-01 14:20:00', true),
(8, 'novikova_o', '$2a$06$tF3XGHOOASwtUYil4M95Wu5EQi8q.QwdEpjz2YiZ/xnTHKubUQGzG', 'novikova@shop.ru', 'Менеджер', 'Новикова Ольга Дмитриевна', '2025-04-15 15:30:00', true),
(9, 'krylov_m', '$2a$06$fYuhsSUXA9HXmOp4ObRLyOIYoB6Cq2r3C/5fg7QnLXj9EHHUeLeSi', 'krylov@shop.ru', 'Администратор', 'Крылов Максим Андреевич', '2025-05-01 16:40:00', true),
(10, 'orlova_y', '$2a$06$EytOfTmjg9OksYf0flFIV.PYCn1l3hTtUHHbllACXXPEKUADaDtUG', 'orlova@shop.ru', 'Складской', 'Орлова Юлия Викторовна', '2025-05-10 17:50:00', true);

INSERT INTO ref.payment_method (method_id, method_name, description) VALUES
(1, 'Карта', 'Оплата картой'),
(2, 'Наличные', 'Оплата наличными');

INSERT INTO ref.product_category (category_id, category_name, description) VALUES
(1, 'Электроника', 'Гаджеты и электроника'),
(2, 'Книги', 'Книги и учебники'),
(3, 'Одежда', 'Мужская и женская одежда'),
(4, 'Дом и сад', 'Товары для дома'),
(5, 'Косметика', 'Косметические средства'),
(6, 'Спорт', 'Товары для спорта');

INSERT INTO app.products (product_id, category_id, product_name, price, stock_quantity, article, is_active) VALUES
(1, 1, 'Samsung Galaxy A55', 34990.00, 20, 'ART-SM-0001', true),
(2, 1, 'Наушники Sony WH-1000', 24990.00, 35, 'ART-SM-0002', true),
(3, 2, 'Книга: Чистый код', 1890.00, 40, 'ART-BK-0001', true),
(4, 3, 'Джинсы Levis 501', 6990.00, 60, 'ART-CL-0001', true),
(5, 4, 'Настольная лампа LED', 2450.00, 25, 'ART-HH-0001', true),
(6, 5, 'Шампунь Head&Shoulders', 590.00, 80, 'ART-CM-0001', true),
(7, 6, 'Гантели 10кг', 3990.00, 15, 'ART-SP-0001', true),
(8, 1, 'Планшет Xiaomi Pad 6', 29990.00, 12, 'ART-SM-0003', true),
(9, 2, 'Книга: PostgreSQL 17', 2490.00, 18, 'ART-BK-0002', true),
(10, 3, 'Куртка зимняя мужская', 12990.00, 10, 'ART-CL-0002', true),
(11, 1, 'Ноутбук Lenovo IdeaPad', 54990.00, 8, 'ART-SM-0004', true);

INSERT INTO app.orders (order_id, client_id, payinfo_id, order_date, status, total_amount, delivery_address, date_of_creation) VALUES
(1, 1, 101, '2025-11-02', 'Создан', 34990.00, 'Москва, ул. Тверская, д.15', '2025-11-02 10:00:00'),
(2, 2, 102, '2025-11-03', 'Оплачен', 27480.00, 'Санкт-Петербург, Невский пр., д.42', '2025-11-03 11:30:00'),
(3, 3, 103, '2025-11-04', 'В обработке', 1890.00, 'Казань, ул. Баумана, д.8', '2025-11-04 12:15:00'),
(4, 4, 104, '2025-11-05', 'Отправлен', 6990.00, 'Новосибирск, ул. Красный пр., д.100', '2025-11-05 13:45:00'),
(5, 5, 105, '2025-11-06', 'Доставлен', 2450.00, 'Екатеринбург, ул. Ленина, д.24', '2025-11-06 14:20:00'),
(6, 6, 106, '2025-11-07', 'Отменен', 590.00, 'Нижний Новгород, ул. Большая Покровская, д.5', '2025-11-07 15:00:00'),
(7, 7, 107, '2025-11-08', 'Создан', 3990.00, 'Челябинск, ул. Кирова, д.12', '2025-11-08 16:30:00'),
(8, 8, 108, '2025-11-09', 'Оплачен', 29990.00, 'Самара, ул. Ново-Садовая, д.30', '2025-11-09 17:15:00'),
(9, 9, 109, '2025-11-10', 'Доставлен', 2490.00, 'Омск, ул. Ленина, д.7', '2025-11-10 18:00:00'),
(10, 10, 110, '2025-11-11', 'В обработке', 12990.00, 'Ростов-на-Дону, ул. Большая Садовая, д.50', '2025-11-11 19:20:00');

-- ВНИМАНИЕ: payment_information требует pgcrypto, но карты зашифрованы (card_number, card_cvv).
-- Проще всего оставить их NULL для новых клиентов, чтобы не возиться с шифрованием.
INSERT INTO app.payment_information (payinfo_id, client_id, method_id, card_number, card_cvv, card_expiry) VALUES
(101, 1, 1, NULL, NULL, '2025-11-30'),
(102, 2, 1, NULL, NULL, '2025-08-31'),
(103, 3, 1, NULL, NULL, '2025-12-31'),
(104, 4, 2, NULL, NULL, NULL),
(105, 5, 1, NULL, NULL, '2025-07-31'),
(106, 6, 1, NULL, NULL, '2026-01-31'),
(107, 7, 2, NULL, NULL, NULL),
(108, 8, 1, NULL, NULL, '2025-09-30'),
(109, 9, 1, NULL, NULL, '2025-10-31'),
(110, 10, 1, NULL, NULL, '2025-06-30');

INSERT INTO app.order_items (order_id, product_id) VALUES
(1, 1), (2, 2), (2, 3), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10), (10, 11);

INSERT INTO audit.audit_log (audit_log_id, staff_id, action_time, action_type, action_description, success) VALUES
(1, 1, '2025-01-11 09:10:00', 'CREATE', 'Создан профиль клиента', true),
(2, 2, '2025-01-12 10:20:00', 'UPDATE', 'Обновлены справочные данные', true),
(3, 3, '2025-02-15 11:30:00', 'DELETE', 'Удалён тестовый объект', false),
(4, 1, '2025-03-01 12:40:00', 'UPDATE', 'Изменение статуса заказа', true),
(5, 4, '2025-04-02 13:50:00', 'CREATE', 'Добавлен новый товар', true),
(6, 5, '2025-05-03 14:00:00', 'OTHER', 'Выполнение служебной операции', true),
(7, 6, '2025-06-04 15:10:00', 'CREATE', 'Создан складской отчёт', true),
(8, 7, '2025-07-05 16:20:00', 'UPDATE', 'Подправлены цены', true),
(9, 8, '2025-08-06 17:30:00', 'DELETE', 'Удаление дубликата', true),
(10, 9, '2025-09-07 18:40:00', 'OTHER', 'Тестовая запись аудита', true),
(11, 2, '2025-10-18 17:49:05.637612', 'CREATE', 'Таблица: products, действие: INSERT', true);

SELECT pg_catalog.setval('app.clients_id_seq', 10, true);
SELECT pg_catalog.setval('app.orders_order_id_seq', 10, true);
SELECT pg_catalog.setval('app.payment_information_info_id_seq', 110, true);
SELECT pg_catalog.setval('app.products_product_id_seq', 11, true);
SELECT pg_catalog.setval('app.staff_staff_id_seq', 10, true);
SELECT pg_catalog.setval('audit.audit_log_audit_log_id_seq', 11, true);
SELECT pg_catalog.setval('ref.payment_method_method_id_seq', 2, true);
SELECT pg_catalog.setval('ref.product_category_category_id_seq', 6, true);


ALTER TABLE ONLY app.clients ADD CONSTRAINT clients_email_key UNIQUE (email);
ALTER TABLE ONLY app.clients ADD CONSTRAINT clients_phone_number_key UNIQUE (phone_number);
ALTER TABLE ONLY app.clients ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);
ALTER TABLE ONLY app.order_items ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, product_id);
ALTER TABLE ONLY app.orders ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);
ALTER TABLE ONLY app.payment_information ADD CONSTRAINT payment_information_pkey PRIMARY KEY (payinfo_id);
ALTER TABLE ONLY app.products ADD CONSTRAINT products_article_key UNIQUE (article);
ALTER TABLE ONLY app.products ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);
ALTER TABLE ONLY app.staff ADD CONSTRAINT staff_email_key UNIQUE (email);
ALTER TABLE ONLY app.staff ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);
ALTER TABLE ONLY app.staff ADD CONSTRAINT staff_username_key UNIQUE (username);
ALTER TABLE ONLY audit.audit_log ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_log_id);
ALTER TABLE ONLY ref.payment_method ADD CONSTRAINT payment_method_method_name_key UNIQUE (method_name);
ALTER TABLE ONLY ref.payment_method ADD CONSTRAINT payment_method_pkey PRIMARY KEY (method_id);
ALTER TABLE ONLY ref.product_category ADD CONSTRAINT product_category_category_name_key UNIQUE (category_name);
ALTER TABLE ONLY ref.product_category ADD CONSTRAINT product_category_pkey PRIMARY KEY (category_id);


CREATE INDEX idx_clients_status ON app.clients USING btree (status);
CREATE INDEX idx_orders_client ON app.orders USING btree (client_id);
CREATE INDEX idx_payment_client ON app.payment_information USING btree (client_id);


CREATE TRIGGER trg_log_admins_changes AFTER INSERT OR DELETE OR UPDATE ON app.staff FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_clients_changes AFTER INSERT OR DELETE OR UPDATE ON app.clients FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_orders_changes AFTER INSERT OR DELETE OR UPDATE ON app.orders FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_payment_information_changes AFTER INSERT OR DELETE OR UPDATE ON app.payment_information FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_products_changes AFTER INSERT OR DELETE OR UPDATE ON app.products FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_payment_method_changes AFTER INSERT OR DELETE OR UPDATE ON ref.payment_method FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();
CREATE TRIGGER trg_log_product_category_changes AFTER INSERT OR DELETE OR UPDATE ON ref.product_category FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


ALTER TABLE ONLY app.order_items ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES app.orders(order_id) ON DELETE CASCADE;
ALTER TABLE ONLY app.order_items ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.products(product_id) ON DELETE CASCADE;
ALTER TABLE ONLY app.orders ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;
ALTER TABLE ONLY app.orders ADD CONSTRAINT orders_payinfo_id_fkey FOREIGN KEY (payinfo_id) REFERENCES app.payment_information(payinfo_id);
ALTER TABLE ONLY app.payment_information ADD CONSTRAINT payment_information_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;
ALTER TABLE ONLY app.payment_information ADD CONSTRAINT payment_information_method_id_fkey FOREIGN KEY (method_id) REFERENCES ref.payment_method(method_id);
ALTER TABLE ONLY app.products ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES ref.product_category(category_id);
ALTER TABLE ONLY audit.audit_log ADD CONSTRAINT audit_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES app.staff(staff_id);


GRANT USAGE ON SCHEMA app TO app_reader;
GRANT USAGE ON SCHEMA app TO app_writer;
GRANT ALL ON SCHEMA app TO ddl_admin;
GRANT USAGE ON SCHEMA app TO dml_admin;
GRANT USAGE ON SCHEMA app TO security_admin;

GRANT USAGE ON SCHEMA audit TO auditor;
GRANT ALL ON SCHEMA audit TO ddl_admin;
GRANT USAGE ON SCHEMA audit TO security_admin;

GRANT ALL ON SCHEMA public TO ddl_admin;

GRANT USAGE ON SCHEMA ref TO app_reader;
GRANT USAGE ON SCHEMA ref TO app_writer;
GRANT USAGE ON SCHEMA ref TO app_owner;
GRANT ALL ON SCHEMA ref TO ddl_admin;
GRANT USAGE ON SCHEMA ref TO dml_admin;
GRANT USAGE ON SCHEMA ref TO security_admin;

GRANT ALL ON SCHEMA stg TO ddl_admin;
GRANT USAGE ON SCHEMA stg TO dml_admin;
GRANT USAGE ON SCHEMA stg TO security_admin;

GRANT SELECT ON TABLE app.clients TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.clients TO app_writer;
GRANT ALL ON TABLE app.clients TO app_owner;
GRANT SELECT ON TABLE app.clients TO auditor;
GRANT ALL ON TABLE app.clients TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.clients TO dml_admin;

GRANT SELECT ON TABLE app.order_items TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items TO app_writer;
GRANT ALL ON TABLE app.order_items TO app_owner;
GRANT SELECT ON TABLE app.order_items TO auditor;
GRANT ALL ON TABLE app.order_items TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items TO dml_admin;

GRANT SELECT ON TABLE app.orders TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO app_writer;
GRANT ALL ON TABLE app.orders TO app_owner;
GRANT SELECT ON TABLE app.orders TO auditor;
GRANT ALL ON TABLE app.orders TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO dml_admin;

GRANT SELECT ON TABLE app.payment_information TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.payment_information TO app_writer;
GRANT ALL ON TABLE app.payment_information TO app_owner;
GRANT SELECT ON TABLE app.payment_information TO auditor;
GRANT ALL ON TABLE app.payment_information TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.payment_information TO dml_admin;

GRANT SELECT ON TABLE app.products TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.products TO app_writer;
GRANT ALL ON TABLE app.products TO app_owner;
GRANT SELECT ON TABLE app.products TO auditor;
GRANT ALL ON TABLE app.products TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.products TO dml_admin;

GRANT SELECT ON TABLE app.staff TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.staff TO app_writer;
GRANT ALL ON TABLE app.staff TO app_owner;
GRANT SELECT ON TABLE app.staff TO auditor;
GRANT ALL ON TABLE app.staff TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.staff TO dml_admin;

GRANT SELECT ON TABLE audit.audit_log TO auditor;
GRANT SELECT ON TABLE audit.login_log TO auditor;

GRANT SELECT ON TABLE pg_catalog.pg_auth_members TO security_admin;
GRANT SELECT ON TABLE pg_catalog.pg_namespace TO security_admin;
GRANT SELECT ON TABLE pg_catalog.pg_roles TO security_admin;
GRANT SELECT ON TABLE pg_catalog.pg_tables TO security_admin;

GRANT SELECT ON TABLE ref.payment_method TO app_reader;
GRANT SELECT ON TABLE ref.payment_method TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.payment_method TO dml_admin;

GRANT SELECT ON TABLE ref.product_category TO app_reader;
GRANT SELECT ON TABLE ref.product_category TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.product_category TO dml_admin;

-- На sequences
GRANT ALL ON SEQUENCE app.clients_id_seq TO app_writer, app_owner, ddl_admin, dml_admin;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO app_writer, app_owner, ddl_admin, dml_admin;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO app_writer, app_owner, ddl_admin, dml_admin;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO app_writer, app_owner, ddl_admin, dml_admin;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO app_writer, app_owner, ddl_admin, dml_admin;
GRANT ALL ON SEQUENCE ref.payment_method_method_id_seq TO dml_admin;
GRANT ALL ON SEQUENCE ref.product_category_category_id_seq TO dml_admin;


ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON SEQUENCES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO dml_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT USAGE ON SEQUENCES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON FUNCTIONS TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON TABLES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT USAGE ON SEQUENCES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT ON TABLES TO auditor;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT USAGE ON SEQUENCES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT USAGE ON SEQUENCES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT USAGE ON SEQUENCES TO dml_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT USAGE ON SEQUENCES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT USAGE ON SEQUENCES TO dml_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


CREATE EVENT TRIGGER login_audit_tg ON login
   EXECUTE FUNCTION audit.login_audit();
ALTER EVENT TRIGGER login_audit_tg OWNER TO postgres;

-- ============================================================
-- ГОТОВО
-- ============================================================
