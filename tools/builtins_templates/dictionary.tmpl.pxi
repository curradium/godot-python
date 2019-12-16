{%- set gd_functions = cook_c_signatures("""
// GDAPI: 1.0
void godot_dictionary_new(godot_dictionary* r_dest)
void godot_dictionary_new_copy(godot_dictionary* r_dest, godot_dictionary* p_src)
void godot_dictionary_destroy(godot_dictionary* p_self)
godot_int godot_dictionary_size(godot_dictionary* p_self)
godot_bool godot_dictionary_empty(godot_dictionary* p_self)
void godot_dictionary_clear(godot_dictionary* p_self)
godot_bool godot_dictionary_has(godot_dictionary* p_self, godot_variant* p_key)
godot_bool godot_dictionary_has_all(godot_dictionary* p_self, godot_array* p_keys)
void godot_dictionary_erase(godot_dictionary* p_self, godot_variant* p_key)
godot_int godot_dictionary_hash(godot_dictionary* p_self)
godot_array godot_dictionary_keys(godot_dictionary* p_self)
godot_array godot_dictionary_values(godot_dictionary* p_self)
godot_variant godot_dictionary_get(godot_dictionary* p_self, godot_variant* p_key)
void godot_dictionary_set(godot_dictionary* p_self, godot_variant* p_key, godot_variant* p_value)
// godot_variant* godot_dictionary_operator_index(godot_dictionary* p_self, godot_variant* p_key)
// godot_variant* godot_dictionary_operator_index_const(godot_dictionary* p_self, godot_variant* p_key)
// godot_variant* godot_dictionary_next(godot_dictionary* p_self, godot_variant* p_key)
godot_bool godot_dictionary_operator_equal(godot_dictionary* p_self, godot_dictionary* p_b)
godot_string godot_dictionary_to_json(godot_dictionary* p_self)
godot_bool godot_dictionary_erase_with_return(godot_dictionary* p_self, godot_variant* p_key)
// GDAPI: 1.1
godot_variant godot_dictionary_get_with_default(godot_dictionary* p_self, godot_variant* p_key, godot_variant* p_default)
// GDAPI: 1.2
godot_dictionary godot_dictionary_duplicate(godot_dictionary* p_self, godot_bool p_deep)
""") -%}

{%- block pxd_header %}
{% endblock -%}
{%- block pyx_header %}
{% endblock -%}


@cython.final
cdef class Dictionary:
{% block cdef_attributes %}
    cdef godot_dictionary _gd_data
{% endblock %}

{% block python_defs %}
    def __init__(self, iterable=None):
        if not iterable:
            gdapi10.godot_dictionary_new(&self._gd_data)
        elif isinstance(iterable, Dictionary):
            gdapi10.godot_dictionary_new_copy(&self._gd_data, &(<Dictionary>iterable)._gd_data)
        # TODO: handle Pool*Array
        elif isinstance(iterable, dict):
            gdapi10.godot_dictionary_new(&self._gd_data)
            for k, v in iterable.items():
                self[k] = v
        else:
            try:
                for k, v in iterable:
                    self[k] = v
            except ValueError:
                raise ValueError("dictionary update sequence element #0 has length 1; 2 is required")

    def __dealloc__(self):
        # /!\ if `__init__` is skipped, `_gd_data` must be initialized by
        # hand otherwise we will get a segfault here
        gdapi10.godot_dictionary_destroy(&self._gd_data)

    def __repr__(self):
        return f"<Dictionary({dict(self)})>"

    def __getitem__(self, object key):
        cdef godot_variant var_key
        pyobj_to_godot_variant(key, &var_key)
        cdef godot_variant *p_var_ret = gdapi10.godot_dictionary_operator_index(&self._gd_data, &var_key)
        gdapi10.godot_variant_destroy(&var_key)
        if p_var_ret == NULL:
            raise KeyError(key)
        else:
            return godot_variant_to_pyobj(p_var_ret)

{%set contains_specs = gd_functions['set'] | merge(pyname="__setitem__") %}
    {{ render_method(**contains_specs) | indent }}

    def __delitem__(self, object key):
        cdef godot_variant var_key
        pyobj_to_godot_variant(key, &var_key)
        cdef godot_bool ret = gdapi11.godot_dictionary_erase_with_return(&self._gd_data, &var_key)
        if not ret:
            raise KeyError(key)
        gdapi10.godot_variant_destroy(&var_key)

    def __iter__(self):
        cdef godot_variant *p_key = NULL
        # TODO: mid iteration mutation should throw exception ?
        while True:
            p_key = gdapi10.godot_dictionary_next(&self._gd_data, p_key)
            if p_key == NULL:
                return
            yield godot_variant_to_pyobj(p_key)

    def __copy__(self):
        return self.duplicate(False)

    def __deepcopy__(self):
        return self.duplicate(True)

    def __eq__(self, Dictionary other):
        try:
            return Dictionary.operator_equal(self, other)
        except TypeError:
            return False

    def __ne__(self, object other):
        try:
            return not Dictionary.operator_equal(self, other)
        except TypeError:
            return False

    def __contains__(self, object key):
        return Dictionary.operator_contains(self, key)

    # TODO: support __iadd__ for other types than Dictionary ?
    def __iadd__(self, Dictionary items):
        cdef godot_variant *p_value
        cdef godot_variant *p_key = NULL
        while True:
            p_value = gdapi10.godot_dictionary_next(&items._gd_data, p_key)
            if p_value == NULL:
                break
            gdapi10.godot_dictionary_set(&self._gd_data, p_key, p_value)
        return self

    # TODO: support __add__ for other types than Dictionary ?
    def __add__(Dictionary self, Dictionary items):
        cdef Dictionary dictionary = Dictionary.new()
        cdef godot_variant *p_value
        cdef godot_variant *p_key = NULL
        while True:
            p_value = gdapi10.godot_dictionary_next(&items._gd_data, p_key)
            if p_value == NULL:
                break
            gdapi10.godot_dictionary_set(&dictionary._gd_data, p_key, p_value)
        p_key = NULL
        while True:
            p_value = gdapi10.godot_dictionary_next(&self._gd_data, p_key)
            if p_value == NULL:
                break
            gdapi10.godot_dictionary_set(&dictionary._gd_data, p_key, p_value)
        return dictionary

    def get(self, object key, object default=None):
        cdef godot_variant var_key
        pyobj_to_godot_variant(key, &var_key)
        cdef godot_variant var_ret
        cdef godot_variant var_default
        if default is not None:
            pyobj_to_godot_variant(default, &var_default)
            var_ret = gdapi11.godot_dictionary_get_with_default(&self._gd_data, &var_key, &var_default)
            gdapi10.godot_variant_destroy(&var_default)
        else:
            var_ret = gdapi10.godot_dictionary_get(&self._gd_data, &var_key)
        gdapi10.godot_variant_destroy(&var_key)
        cdef object ret = godot_variant_to_pyobj(&var_ret)
        gdapi10.godot_variant_destroy(&var_ret)
        return ret

{%set len_specs = gd_functions['size'] | merge(pyname="__len__") %}
    {{ render_method(**len_specs) | indent }}

{%set hash_specs = gd_functions['hash'] | merge(pyname="__hash__") %}
    {{ render_method(**hash_specs) | indent }}

{%set contains_specs = gd_functions['has'] | merge(pyname="__contains__") %}
    {{ render_method(**contains_specs) | indent }}

    {{ render_operator_eq() | indent }}
    {{ render_operator_ne() | indent }}

    {{ render_method(**gd_functions["duplicate"]) | indent }}
    {{ render_method(**gd_functions["size"]) | indent }}
    {{ render_method(**gd_functions["empty"]) | indent }}
    {{ render_method(**gd_functions["clear"]) | indent }}
    {{ render_method(**gd_functions["has"]) | indent }}
    {{ render_method(**gd_functions["has_all"]) | indent }}
    {{ render_method(**gd_functions["erase"]) | indent }}
    {{ render_method(**gd_functions["hash"]) | indent }}
    {{ render_method(**gd_functions["keys"]) | indent }}
    {{ render_method(**gd_functions["values"]) | indent }}
    {{ render_method(**gd_functions["to_json"]) | indent }}
{% endblock %}

{%- block python_consts %}
{% endblock %}
