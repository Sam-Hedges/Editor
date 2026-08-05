#if OS == {
	case .WINDOWS; #load "windows.jai";
	case; #load "unix.jai";
}

check_directory_exists :: (path: string) -> directory_exists: bool {
	return os_check_directory_exists(path);
}

#scope_module

#import "Basic";
#import "String";
#import "File";