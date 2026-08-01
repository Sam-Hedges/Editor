#import "Compiler";
#import "Basic";

build :: () {
    w := compiler_create_workspace("Editor");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

    target_options := get_build_options(w);
    target_options.output_executable_name = "Editor";
    target_options.output_path = "bin/";
    if target_options.
    target_options.backend = .X64;
    set_build_options(target_options, w);

    compiler_begin_intercept(w);
    add_build_file(tprint("%/%", #filepath, "src/main.jai"), w);
    compiler_end_intercept(w);

    set_build_options_dc(.{do_output=false});
}

#run build();
