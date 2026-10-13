
const kSample = r'''
Table users [headercolor: #3B82F6] {
  id integer [pk, increment]
  username varchar(60) [unique, not null]
  email varchar(120) [unique, not null]
  created_at timestamp
}

Table products [headercolor: #3B82F6] {
  id integer [pk]
  name varchar(120) [not null]
  price decimal(10,2)
  category_id integer [ref: > categories.id]
}

Table categories [headercolor: #3B82F6] {
  id integer [pk]
  name varchar
}

Table orders [headercolor: #3B82F6] {
  id integer [pk]
  user_id integer [ref: > users.id]
  status varchar
  created_at timestamp
}

Table order_items [headercolor: #3B82F6] {
  order_id integer [pk]
  product_id integer [pk]
  quantity integer
}

Ref: order_items.order_id > orders.id
Ref: order_items.product_id > products.id
''';