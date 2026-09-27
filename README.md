# Olist Brazilian E-Commerce — PostgreSQL

Домашня робота з баз даних: робота з Brazilian E-Commerce Public Dataset by Olist
у PostgreSQL (через `pixeltable_pgserver` + SQLAlchemy) в Jupyter Notebook.

## Джерело датасету

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle).

## Спосіб отримання файлів

CSV-файли датасету **не зберігаються в репозиторії** — вони завантажуються
автоматично при запуску `hw4.ipynb` у папку `data/`. Локальна PostgreSQL база
(`pgserver`) також ініціалізується автоматично в папці `temp/` при першому
запуску ноутбука.

Нічого вручну завантажувати не потрібно — достатньо виконати ноутбук
`hw4.ipynb` від початку до кінця.

## Використані таблиці

У завданні використано 6 таблиць, побудованих з відповідних CSV-файлів датасету:

| Таблиця              | Джерело (CSV)                        | Опис                                  |
|-----------------------|---------------------------------------|----------------------------------------|
| `olist_customers`     | `olist_customers_dataset.csv`         | Клієнти (customer_id, адреса, штат)   |
| `olist_orders`        | `olist_orders_dataset.csv`            | Замовлення та їхні статуси/дати       |
| `olist_products`      | `olist_products_dataset.csv`          | Товари та їхні характеристики         |
| `olist_sellers`       | `olist_sellers_dataset.csv`           | Продавці (seller_id, адреса, штат)    |
| `olist_order_items`   | `olist_order_items_dataset.csv`       | Позиції замовлень (товар, ціна, доставка) |
| `olist_order_reviews` | `olist_order_reviews_dataset.csv`     | Відгуки покупців на замовлення        |

Додатково в межах завдання створені похідні таблиці:

- `seller_score` — агрегований рейтинг та тір продавця
- `olist_customer_dim` — дедуплікована вимірна таблиця клієнтів (за `customer_unique_id`)
- `customer_segments` — поточна сегментація покупців (RFM-подібні фічі)
- `seller_alerts` — таблиця для демонстрації `DELETE ... RETURNING`

## Структура репозиторію

```
data/           # CSV-файли датасету (завантажуються автоматично)
temp/           # локальна PostgreSQL база (pgserver), створюється автоматично
sql_comnds/     # великі SQL-команди (com1.sql – com6.sql), викликаються з hw4.ipynb
hw4.ipynb       # основний файл запуску
```

## Інструкція запуску

1. Встановити залежності:
   ```bash
   %pip install -q pgserver psycopg2-binary sqlalchemy pandas kagglehub
   ```
2. Відкрити `hw4.ipynb` у Jupyter.
3. Виконати всі клітинки послідовно (`Run All`):
   - CSV-файли датасету автоматично завантажаться в `data/`;
   - локальна PostgreSQL база розгорнеться в `temp/` через `pgserver`;
   - дані з CSV будуть завантажені у типізовані таблиці;
   - SQL-скрипти з `sql_comnds/` (`com1.sql`–`com6.sql`) виконаються через
     SQLAlchemy (`create_engine`, `text`) для створення схеми, DML-операцій
     та аналітичних запитів.
4. Результати запитів (JOIN, агрегації, set-операції) виводяться в самому
   ноутбуці разом з business-question та інтерпретацією.

## Технологічний стек

- **PostgreSQL** (локально через `pixeltable_pgserver`)
- **SQLAlchemy** (`create_engine`, `text`) — виконання SQL з Python
- **Jupyter Notebook**
