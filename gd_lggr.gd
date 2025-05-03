class_name Lggr extends Resource

@export var level: int = 0
var criteria: Dictionary


func log(text: String, output_type: String) -> void:
    var print_callable: Callable = print
    if output_type == "err":
        print_callable = printerr

    if level < 1:
        print_callable.call(text)

    elif level < 2:
        print_callable.call(text)
    
    else:
        if print_callable == printerr:
            print_callable.call(text)