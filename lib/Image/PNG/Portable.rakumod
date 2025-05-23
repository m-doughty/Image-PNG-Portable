unit class Image::PNG::Portable;

use String::CRC32;
use Compress::Zlib;

has Int $.width  is required;
has Int $.height is required;
has Bool $.alpha = True;

has $!channels = $!alpha ?? 4 !! 3;
# + 1 allows filter bytes in the raw data, avoiding needless buf manip later
has $!line-bytes = $!width * $!channels + 1;
has $!data-bytes = $!line-bytes * $!height;
has $!data = do { my $b = buf8.new; $b[$!data-bytes-1] = 0; $b; };

# magic string for PNGs
my $magic = Blob.new: 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A;

method set(
    Int $x where * < $!width,
    Int $y where * < $!height,
    Int $r, Int $g, Int $b, Int $a = 255
) {
    my $buffer = $!data;
    # + 1 skips aforementioned filter byte
    my $index = $!line-bytes * $y + $!channels * $x + 1;

    $buffer[$index++] = $r;
    $buffer[$index++] = $g;
    $buffer[$index  ] = $b;
    $buffer[++$index] = $a if $!alpha;

    True
}

method set-all(Int:D $r, Int:D $g, Int:D $b, Int:D $a = 255) {
    my $buffer = $!data;
    my $index = 0;
    my $alpha = $!alpha;

    for ^$!height {
        # every line offset by 1 again for filter byte
        $index++;
        for ^$!width {
            $buffer[$index++] = $r;
            $buffer[$index++] = $g;
            $buffer[$index++] = $b;
            $buffer[$index++] = $a if $alpha;
        }
    }

    True
}

method get(
    Int:D $x where * < $!width,
    Int:D $y where * < $!height
) {
    my $buffer = $!data;
    # + 1 skips aforementioned filter byte
    my $index = $!line-bytes * $y + $!channels * $x + 1;

    my @ret = $buffer[$index++], $buffer[$index++], $buffer[$index];
    @ret[3] = $buffer[++$index] if $!alpha;
    @ret
}

method write(Str:D $file) {
    my $fh = $file.IO.open(:w, :bin);

    $fh.write: $magic;

    write-chunk $fh, 'IHDR', @(bytes($!width, 4).Slip, bytes($!height, 4).Slip,
        8, ($!alpha ?? 6 !! 2), 0, 0, 0); # w, h, bits/channel, color, compress, filter, interlace

    # would love to skip compression for my purposes, but PNG mandates it
    # splitting the data into multiple chunks would be good past a certain size
    # for now I'd rather expose weak spots in the pipeline wrt large data sets
    # PNG allows chunks up to (but excluding) 2GB (after compression for IDAT)
    write-chunk $fh, 'IDAT', compress $!data;

    write-chunk $fh, 'IEND';

    $fh.close;

    True
}

# writes a chunk
sub write-chunk (IO::Handle:D $fh, Str:D $type, @data = ()) {
    $fh.write: bytes @data.elems, 4;

    my @type := $type.encode;
    my @td := @data ~~ Blob ??
        @type ~ @data !!
        Blob[uint8].new: @type.list, @data.list;
    $fh.write: @td;

    $fh.write: bytes String::CRC32::crc32 @td;

    True
}

# converts a number to a Blob of bytes with optional fixed width
sub bytes (Int:D $n is copy, Int:D $count = 0) {
    my @return;

    my $exp = 1;
    $exp++ while 256 ** $exp <= $n;

    if $count {
        my $diff = $exp - $count;
        die 'Overflow' if $diff > 0;
        @return.append(0 xx -$diff) if $diff < 0;
    }

    while $exp {
        my $scale = 256 ** --$exp;
        my $value = $n div $scale;
        @return.push: $value;
        $n -= $value * $scale;
    }

    Blob[uint8].new: @return;
}

# vim: expandtab shiftwidth=4
