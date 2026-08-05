#scope_module

os_check_directory_exists :: (path: string) -> directory_exists: bool {
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
}

#scope_file

Windows 	 :: #import "Windows";
Windows_Utf8 :: #import "Windows_Utf8";
System 		 :: #import "System";

using Windows;
using Windows_Utf8;