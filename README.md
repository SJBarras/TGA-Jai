# TGA-Jai
TGA parser for Jai

Clone / place into ```jai/modules/TGA``` and use like so:

```jai
#import "Basic";
TGA :: #import "TGA";
FP :: #import "Flat_Pool";

main :: ()
{
	// Using big targa struct

	file_data, success := read_entire_file("my_image.tga");

	parse_success, targa := TGA.parse(file_data);
	assert(parse_success, "Couldn't parse TGA\n");

	print("Is TGA 2.0: %\n",				targa.extension_area.(bool));
	print("Has postage stamp: %\n", 			targa.postage_stamp.count > 0);
	print("Has scan line table: %\n", 			targa.scan_line_table.count > 0);
	print("Has color correction table: %\n", 		targa.color_correction_table.count > 0);
	print("Has color map: %\n", 				targa.color_map.count > 0);
	print("Has dev directory: %\n", 			targa.dev_directory.count > 0);

	do_something_with_pixel_data(targa.pixels);


	// Extracting pixel data without other TGA stuff

	pixel_pool: FP.Flat_Pool;
	extract_success, just_pixels, descriptor := TGA.extract_pixels(
		binary=file_data,
		valid_pixel_depths=.[8, 24, 32],
		allocate=true,,
		Allocator.{proc=FP.flat_pool_allocator_proc, data=*pixel_pool});
	assert(extract_success, "Failed to extract pixel data");
	assert(descriptor.image_origin == .BOTTOM_LEFT);

	do_something_with_pixel_data(just_pixels);
}
```