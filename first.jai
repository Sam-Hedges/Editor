#import "Compiler";
#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";

#if OS == .WINDOWS {
	// TODO(Sam): Pull these imports out into a clone of the File module
	// along with check_directory_exists procedure 
	Windows 	 :: #import "Windows";
	Windows_Utf8 :: #import "Windows_Utf8";
	System 		 :: #import "System";

	using Windows;
	using Windows_Utf8;
}

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

check_directory_exists :: (path: string) -> directory_exists: bool {
	if OS == .WINDOWS {
	    // -12 comes from it also needing to include 8.3 for file names
    	MAX_DIRECTORY_PATH :: MAX_PATH - 12;

    	LONG_PATH_PREFIX :: "\\\\?\\";

    	path_wide := utf8_to_wide(path,, allocator=temp);

    	// GetFileAttributes does not support paths larger than MAX_DIRECTORY_PATH unless they start with LONG_PATH_PREFIX
		if !begins_with(path, LONG_PATH_PREFIX) {
            full_path_size := GetFullPathNameW(path_wide, 0, null, null); // returns the size in WCHARs _including_ the terminating 0.
            if !full_path_size {
                error_code, error_string := System.get_error_value_and_string();
                log_error("In make_directory_helper(), GetFullPathNameW (without buffer) failed: % %", error_code, error_string);
                return false;
            }
	       
            if full_path_size > MAX_DIRECTORY_PATH {
                prefixed_full_path_size := full_path_size + LONG_PATH_PREFIX.count; // Size in WCHARs with the prefix
                full_path_wide: *u16 = temporary_alloc(prefixed_full_path_size * 2);
                memcpy(full_path_wide, utf8_to_wide(LONG_PATH_PREFIX,, allocator=temp), LONG_PATH_PREFIX.count * 2); 

				// returns the size in WCHARs _not including_ the terminating 0.
                real_full_path_size := GetFullPathNameW(path_wide, full_path_size, full_path_wide + LONG_PATH_PREFIX.count, null); 
	       
                if !real_full_path_size {
                    error_code, error_string := System.get_error_value_and_string();
                    log_error("In make_directory_helper(), GetFullPathNameW (with buffer) failed: % %", error_code, error_string);
                    return false;
                }
                assert(real_full_path_size <= full_path_size - 1); // -1 because on success, it does NOT include the null character, but on failure it does. This used to be ==, but in some cases we get a shorter path... I guess the return value of GetFullPathNameW is inexact in some cases!
	       
                path_wide = full_path_wide;
            }
		}

		attribs := GetFileAttributesW(path_wide);

		if attribs == INVALID_FILE_ATTRIBUTES return false;

		return (attribs & FILE_ATTRIBUTE_DIRECTORY) != 0;

		//err := GetLastError();
		//if err == INVALID_FILE_ATTRIBUTES return false;
		
	} else {
		assert(false, "You need to implement (%) for %", #procedure_name(), OS);
	}
	return false;
}

#run build();
