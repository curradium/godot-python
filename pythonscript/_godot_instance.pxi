# cython: c_string_type=unicode, c_string_encoding=utf8

from libc.stddef cimport wchar_t
from cpython cimport Py_INCREF, Py_DECREF, PyObject

from godot._hazmat.gdnative_api_struct cimport (
    godot_string,
    godot_string_name,
    godot_bool,
    godot_array,
    godot_pool_string_array,
    godot_object,
    godot_variant,
    godot_variant_call_error,
    godot_method_rpc_mode,
    godot_pluginscript_script_data,
    godot_pluginscript_instance_data,
    godot_variant_call_error_error,
    godot_variant_type,
)
from godot._hazmat.gdapi cimport pythonscript_gdapi10 as gdapi10
from godot._hazmat.conversion cimport (
    godot_variant_to_pyobj,
    pyobj_to_godot_variant,
    godot_string_name_to_pyobj,
)


cdef api godot_pluginscript_instance_data* pythonscript_instance_init(
    godot_pluginscript_script_data *p_data,
    godot_object *p_owner
):
    cdef object instance = (<object>p_data)()
    (<Object>instance)._gd_ptr = p_owner
    Py_INCREF(instance)
    return <void *>instance


cdef api void pythonscript_instance_finish(
    godot_pluginscript_instance_data *p_data
):
    Py_DECREF(<object>p_data)


cdef api godot_bool pythonscript_instance_set_prop(
    godot_pluginscript_instance_data *p_data,
    const godot_string *p_name,
    const godot_variant *p_value
):
    cdef object instance = <object>p_data
    try:
        setattr(instance, godot_string_to_pyobj(p_name), godot_variant_to_pyobj(p_value))
        return True
    except Exception:
        traceback.print_exc()
        return False


cdef api godot_bool pythonscript_instance_get_prop(
    godot_pluginscript_instance_data *p_data,
    const godot_string *p_name,
    godot_variant *r_ret
):
    cdef object instance = <object>p_data
    cdef object ret
    try:
        ret = getattr(instance, godot_string_to_pyobj(p_name))
        pyobj_to_godot_variant(ret, r_ret)
        return True
    except Exception:
        traceback.print_exc()
        return False


cdef api godot_variant pythonscript_instance_call_method(
    godot_pluginscript_instance_data *p_data,
    const godot_string_name *p_method,
    const godot_variant **p_args,
    int p_argcount,
    godot_variant_call_error *r_error
):
    cdef godot_variant var_ret
    cdef object instance = <object>p_data
    # TODO: optimize this by caching godot_string_name -> method lookup
    try:
        meth = getattr(instance, godot_string_name_to_pyobj(p_method))

    except AttributeError:
        r_error.error = godot_variant_call_error_error.GODOT_CALL_ERROR_CALL_ERROR_INVALID_METHOD
        gdapi10.godot_variant_new_nil(&var_ret)
        return var_ret

    cdef int i
    cdef list pyargs
    cdef object ret
    try:
        pyargs = [godot_variant_to_pyobj(p_args[i]) for i in range(p_argcount)]
        ret = meth(*pyargs)
        r_error.error = godot_variant_call_error_error.GODOT_CALL_ERROR_CALL_OK
        pyobj_to_godot_variant(ret, &var_ret)
        return var_ret

    except NotImplementedError:
        r_error.error = godot_variant_call_error_error.GODOT_CALL_ERROR_CALL_ERROR_INVALID_METHOD

    except TypeError:
        traceback.print_exc()
        # TODO: handle errors here
        r_error.error = godot_variant_call_error_error.GODOT_CALL_ERROR_CALL_ERROR_INVALID_ARGUMENT
        r_error.argument = 1
        r_error.expected = godot_variant_type.GODOT_VARIANT_TYPE_NIL
    except Exception:
        traceback.print_exc()
        r_error.error = godot_variant_call_error_error.GODOT_CALL_ERROR_CALL_ERROR_INVALID_METHOD

    # TODO: also catch other exceptions types ?

    # Something bad occured, return a default None variant
    gdapi10.godot_variant_new_nil(&var_ret)
    return var_ret


cdef api void pythonscript_instance_notification(
    godot_pluginscript_instance_data *p_data,
    int p_notification
):
    cdef object instance = <object>p_data
    # Godot's notification should call all parent `_notification`
    # methods (better not use `super()._notification` in those methods...)
    # TODO: cache the methods to call ?
    for parentcls in instance.__class__.__mro__:
        try:
            # TODO: Should only call _notification for class inheriting `bindings.Object` ?
            parentcls.__dict__["_notification"](instance, p_notification)
        except (KeyError, NotImplementedError):
            pass


# Useful ?

# cdef api void pythonscript_instance_refcount_incremented(
#     godot_pluginscript_instance_data *p_data
# ):
#     pass


# cdef api bool pythonscript_instance_refcount_decremented(
#     godot_pluginscript_instance_data *p_data
# ):
#     pass
