{#
  A simple reusable MACRO. Macros are Jinja functions that return SQL snippets,
  keeping transformations DRY. Used in stg_payments.sql.

  Usage:  {{ dollars_to_cents('amount') }}  ->  cast(round(amount * 100) as bigint)
#}
{% macro dollars_to_cents(column_name) %}
    cast(round({{ column_name }} * 100) as bigint)
{% endmacro %}
