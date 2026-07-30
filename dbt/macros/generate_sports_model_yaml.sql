{% macro generate_sports_model_yaml() %}

    {% set model_names = [] %}
    {% set path_prefix = 'models/sports/nba/' %}

    {% for node in graph.nodes.values() %}
        {% if node.resource_type == 'model'
            and node.package_name == project_name
            and node.original_file_path.startswith(path_prefix) %}

            {% do model_names.append(node.name) %}

        {% endif %}
    {% endfor %}

    {{ codegen.generate_model_yaml(
        model_names=model_names | sort,
        include_data_types=true,
        upstream_descriptions=true
    ) }}

{% endmacro %}