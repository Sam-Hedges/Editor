#import "Compiler";
#import "Basic";
#import "File";
#import "File_Utilities";
#import "File_Custom";
#import "String";

#run build();

build :: () {
    w := compiler_create_workspace("Editor");
    if !w {
        print("Workspace creation failed.\n");
        return;
    }

	make_directory_if_it_does_not_exist(tprint("%0%", #filepath, "bin/"));

    target_options := get_build_options(w);
    target_options.output_executable_name = "Editor";
    target_options.output_path = "bin/";
    target_options.backend = .X64;
	target_options.text_output_flags &= ~.OUTPUT_LINK_LINE;
    set_build_options(target_options, w);

    compiler_begin_intercept(w);
    add_build_file(tprint("%0%", #filepath, "src/main.jai"), w);
	for gather_shaders(tprint("%0%", #filepath, "src/shaders")) {
		add_build_string(it, w);
	}
    compiler_end_intercept(w);

    set_build_options_dc(.{do_output=false});
}

gather_shaders :: (shader_directory: string) -> [] string {

	shader_paths : [] string;

	if !check_directory_exists(shader_directory) 
		return shader_paths;
		
	shader_paths = file_list(shader_directory);

	shader_strings : [..] string;
	
	for shader_paths {
		if !is_valid(file_open(it)) continue;

		shader_body, success := read_entire_file(it);

		if !success continue;

		shader_name := slice(it, find_index_from_right(it, #char "/") + 1, it.count);
		shader_name = slice(shader_name, 0, find_index_from_right(shader_name, #char "."));
		to_upper_in_place(shader_name);

		array_add(*shader_strings, tprint("SHADER_% :: #string END\n%\nEND", shader_name, shader_body));
	}

	return shader_strings;
}

