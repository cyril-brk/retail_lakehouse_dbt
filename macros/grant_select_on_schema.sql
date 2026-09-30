{#
  Operational MACRO you can run with `dbt run-operation`. Grants SELECT on every
  table/view in a schema to a UC principal — handy for publishing marts to BI
  consumers after a build.

  Usage:
    dbt run-operation grant_select_on_schema \
      --args '{schema: core, grantee: "bi_readers"}'
#}
{% macro grant_select_on_schema(schema, grantee) %}
    {% set resolved_schema = generate_schema_name(schema, none) %}
    {% set fqn_schema = adapter.quote(target.catalog) ~ '.' ~ adapter.quote(resolved_schema) %}
    {% set sql %}
        GRANT SELECT ON SCHEMA {{ fqn_schema }} TO `{{ grantee }}`
    {% endset %}
    {% do log("Granting SELECT on " ~ fqn_schema ~ " to " ~ grantee, info=true) %}
    {% do run_query(sql) %}
    {% do log("Done.", info=true) %}
{% endmacro %}
