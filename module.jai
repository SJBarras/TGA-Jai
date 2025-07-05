#scope_file

#import "Basic";

enum_contains :: ($enum_type: Type, value: s64) -> bool
{
	enum_type_info := type_info(enum_type);
	found, index := array_find(enum_type_info.values, value);

	if !found
		print("TGA parsing error: % does not contain value %\n", enum_type, value);

	return found;
}

#scope_export

Image_Origin :: enum u8
{
	BOTTOM_LEFT :: 0;
	BOTTOM_RIGHT :: 1;
	TOP_LEFT :: 2;
	TOP_RIGHT :: 3;
}

Image_Descriptor :: struct
{
	attribute_bits: u8;
	image_origin: Image_Origin;
}

Color_Map_Type :: enum u8 #specified
{
	NOT_INCLUDED :: 0;
	INCLUDED :: 1;
}

Image_Type :: enum u8 #specified
{
	NO_IMAGE_DATA :: 0;
	COLOR_MAPPED :: 1;
	TRUE_COLOR :: 2;
	GRAYSCALE :: 3;
	RLE_COLOR_MAP :: 9;
	RLE_TRUE_COLOR :: 10;
	RLE_GRAYSCALE :: 11;
}

Alpha_Type :: enum u8 #specified
{
	NONE :: 0;
	UNDEFINED_IGNORE :: 1;
	UNDEFINED_RETAIN :: 2;
	PRESENT :: 3;
	PRE_MULTIPLIED :: 4; // PNG style?
}

Color_Map_Specification :: struct
{
	first_entry_index: u16		#align 1;
	length: u16					#align 1;
	entry_size: u8				#align 1;
}

Image_Specification :: struct
{
	x_origin: u16			#align 1;
	y_origin: u16			#align 1;
	width: u16				#align 1;
	height: u16				#align 1;
	pixel_depth: u8			#align 1;
	descriptor_bitflag: u8	#align 1;
}

Header :: struct
{
    id_length: u8 										#align 1;
    color_map_type: Color_Map_Type 						#align 1;
    image_type: Image_Type 								#align 1;
    color_map_specification: Color_Map_Specification 	#align 1;
    image_specification: Image_Specification 			#align 1;
}

Footer :: struct
{
	extension_area_offset: u32	#align 1;
	dev_directory_offset: u32	#align 1;
	signature: [16] u8			#align 1;
	magic_period: u8			#align 1;
	zero_terminator: u8			#align 1;
}

Dev_Directory_Entry :: struct
{
	tag: u16			#align 1;
	field_offset: u32	#align 1;
	field_size: u32		#align 1;
}

Extension_Area :: struct
{
	fixed_portion_length: u16			#align 1;
	author_name: [41] u8				#align 1;
	author_comments: [324] u8			#align 1;
	date_stamp: Date_Stamp				#align 1;
	job_id: [41] u8						#align 1;
	job_time: Job_Time					#align 1;
	software_id: [41] u8				#align 1;
	software_version: Software_Version	#align 1;
	key_color: u32						#align 1;
	pixel_aspect_ratio: [2] u16			#align 1;
	gamma_value: [2] u16				#align 1;
	color_correction_offset: u32		#align 1;
	postage_stamp_offset: u32			#align 1; // aka thumbnail
	scan_line_offset: u32				#align 1;
	alpha_type: Alpha_Type				#align 1;
}

Date_Stamp :: struct
{
	month: u16		#align 1; 	// 1 - 12
	day: u16		#align 1; 		// 1 - 31
	year: u16		#align 1;		// 4 digit year
	hour: u16		#align 1;		// 0 - 23
	minute: u16		#align 1;	// 0 - 59
	second: u16		#align 1;	// 0 - 59
}

Job_Time :: struct
{
	hours: u16		#align 1;
	minutes: u16	#align 1;
	seconds: u16	#align 1;
}

Software_Version :: struct
{
	number: u16		#align 1;
	letter: u8		#align 1;
}

Postage_Stamp :: struct
{
	x_size: u8		#align 1;
	y_size: u8		#align 1;
}

Targa :: struct
{
	header: *Header;
	footer: *Footer;
	id: [] u8;
	color_map: [] u8;
	dev_directory: [] Dev_Directory_Entry;
	extension_area: *Extension_Area;
	scan_line_table: [] u8;
	postage_stamp: [] u8;
	color_correction_table: [] u16;
	pixels: [] u8;
}

validate_header :: inline (header: *Header) -> bool
{
	if !enum_contains(Color_Map_Type, cast(s64) header.color_map_type)
		return false;

	if !enum_contains(Image_Type, cast(s64) header.image_type)
		return false;

	if header.image_type == .RLE_COLOR_MAP || header.image_type == .RLE_TRUE_COLOR || header.image_type == .RLE_GRAYSCALE
	{
		print("Decoding of RLE image type is not supported.\n");
		return false;
	}

	return true;
}

validate_empty_map_spec :: inline (map_spec: *Color_Map_Specification) -> bool
{
	if map_spec.first_entry_index != 0 || map_spec.length != 0 || map_spec.entry_size != 0
	{
		print("TGA error: Invalid specification\n\tColor map indicated as unused but color map specification was non-zero.\n");
		return false;
	}
	else
		return true;
}

get_image_length :: inline (x: u32, y: u32, depth: u32) -> u32
{
	return x * y * (depth / 8);
}

get_image_length :: inline (img_spec: *Image_Specification) -> u32
{
	return get_image_length(img_spec.width, img_spec.height, img_spec.pixel_depth);
}

validate_pixel_depth :: inline (img_spec: *Image_Specification, valid_depths: [] u8) -> bool
{
	if valid_depths.count == 0
		return true;
	else
	{
		found := array_find(valid_depths, img_spec.pixel_depth);
		if !found
		{
			print("Invalid pixel depth '%' not in list of supported values %\n", img_spec.pixel_depth, valid_depths);
			return false;
		}

		return true;
	}
}

extract_image_descriptor :: inline (img_spec: Image_Specification) -> (success: bool, Image_Descriptor)
{
	img_desc: Image_Descriptor;
	img_desc.attribute_bits = img_spec.descriptor_bitflag & 0x0F;
	img_desc.image_origin = cast(Image_Origin) (img_spec.descriptor_bitflag & 0x30) >> 4;

	reserved: u8 = (img_spec.descriptor_bitflag & 0xC0) >> 6;
	if reserved != 0
		return false, .{};

	return true, img_desc;
}

get_origin :: inline (targa: Targa) -> Image_Origin
{
	return cast(Image_Origin) (targa.header.image_specification.descriptor_bitflag & 0x30) >> 4;
}

parse :: (binary: string, valid_pixel_depths: [] u8 = .{}) -> (success: bool, Targa)
{
	image: Targa;
	image.header = cast(*Header) binary.data;

	if !validate_header(image.header)
		return false, .{};

	using map_spec := image.header.color_map_specification;
	using img_spec := image.header.image_specification;

	if !validate_pixel_depth(*img_spec, valid_pixel_depths)
		return false, .{};

	data_cursor := binary.data;
	data_cursor += size_of(Header);

	if image.header.id_length > 0
	{
		image.id.data = data_cursor;
		image.id.count = image.header.id_length;

		data_cursor += image.header.id_length;
	}

	if image.header.color_map_type == .INCLUDED
	{
		entry_bytes := map_spec.entry_size / 8;
		total_map_size := entry_bytes * map_spec.length;

		image.color_map.data = data_cursor;
		image.color_map.count = total_map_size;

		data_cursor += total_map_size;
	}
	else
		validate_empty_map_spec(*map_spec);

	image.pixels.data = data_cursor;
	image.pixels.count = get_image_length(*img_spec);

	image.footer = cast(*Footer) (binary.data + (binary.count - 26));
	signature_str := string.{16, image.footer.signature.data};

	// TGA 2.0
	if signature_str == "TRUEVISION-XFILE" && image.footer.magic_period == #char "."
	{
		if image.footer.extension_area_offset > 0
		{
			image.extension_area = cast(*Extension_Area) (binary.data + image.footer.extension_area_offset);
			using ext := image.extension_area;

			if ext.scan_line_offset > 0
			{
				image.scan_line_table.data = binary.data + ext.scan_line_offset;
				image.scan_line_table.count = img_spec.height;
			}

			if ext.postage_stamp_offset > 0
			{
				postage_stamp_x: *u8 = binary.data + ext.postage_stamp_offset;
				postage_stamp_y: *u8 = binary.data + ext.postage_stamp_offset + size_of(u8);

				image.postage_stamp.data = binary.data + ext.postage_stamp_offset + size_of(u8) + size_of(u8);
				image.postage_stamp.count = postage_stamp_x.* * postage_stamp_y.* * (img_spec.pixel_depth/8);
			}

			if ext.color_correction_offset > 0
			{
				image.color_correction_table.data = cast(*u16) (binary.data + ext.color_correction_offset);
				image.color_correction_table.count = 1024;
			}
		}

		if image.footer.dev_directory_offset > 0
		{
			dev_directory_base: *u8 = binary.data + image.footer.dev_directory_offset;
			dev_directory_length: *u16 = cast (*u16) (dev_directory_base);

			image.dev_directory.count = dev_directory_length.*;
			image.dev_directory.data = cast (*Dev_Directory_Entry) (dev_directory_base + size_of(u16));
		}
	}

	return true, image;
}

extract_pixels :: (binary: string, valid_pixel_depths: [] u8 = .{}, allocate: bool = true) -> (success: bool, [] u8, Image_Descriptor)
{
	img: [] u8;
	header := cast(*Header) binary.data;

	if !validate_header(header)
		return false, .{}, .{};

	using map_spec := header.color_map_specification;
	using img_spec := header.image_specification;

	if !validate_pixel_depth(*img_spec, valid_pixel_depths)
		return false, .{}, .{};

	data_cursor := binary.data;
	data_cursor += size_of(Header);

	if header.id_length > 0
	{
		data_cursor += header.id_length;
	}

	if header.color_map_type == .INCLUDED
	{
		entry_bytes := map_spec.entry_size / 8;
		total_map_size := entry_bytes * map_spec.length;

		data_cursor += total_map_size;
	}
	else
		validate_empty_map_spec(*map_spec);

	img.count = get_image_length(*img_spec);

	img_spec.height * img_spec.width * (img_spec.pixel_depth/8);

	if allocate
	{
		img.data = alloc(img.count);
		memcpy(img.data, data_cursor, img.count);
	}
	else
	{
		img.data = data_cursor;
	}

	img_desc_result, img_desc := extract_image_descriptor(header.image_specification);
	if !img_desc_result
		return false, .{}, .{};

	return true, img, img_desc;
}