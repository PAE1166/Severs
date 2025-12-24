import { pgTable, serial, text, integer, numeric, timestamp } from 'drizzle-orm/pg-core';

export const products = pgTable('products', {
  id: serial('id').primaryKey(),
  cross_ref: text('cross_ref'),
  segment_code: text('segment_code'),
  description: text('description'),
  uom: text('uom'),
  price_cash_1: numeric('price_cash_1'),
  price_cash_2: numeric('price_cash_2'),
  valid_until: timestamp('valid_until'),
});