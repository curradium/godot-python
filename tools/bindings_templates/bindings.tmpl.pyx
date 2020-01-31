# /!\ Autogenerated code, modifications will be lost /!\
# see `tools/generate_bindings.py`

from godot._hazmat.gdnative_api_struct cimport *
from godot._hazmat.gdapi cimport pythonscript_gdapi10 as gdapi10
from godot._hazmat.conversion cimport *
from godot.builtins cimport *

### Classes ###

{% from 'class.tmpl.pyx' import render_class -%}
{%- for cls in classes %}
{{ render_class(cls) }}
{%- endfor %}

### Singletons ###

{% include "singletons.tmpl.pyx" %}

### Global constants ###

{% include "global_constants.tmpl.pyx" %}
