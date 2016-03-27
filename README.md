# GeniTag
EPC generator

Use this app to generate EPC encodings for performance testing.  It can encode DPCI's in a GID, or UPC barcodes
in an SGTIN.

Note: The input file should be a csv containing barcodes to be encoded.  You are limited by memory as to how
many you can create on a single run.  It has been shown that for 1000 barcodes, you can generate up to 40 EPCs
per barcode per run.  Each run's output file will have the number of EPCs appended to the output file name.

Here are the run capacities that worked:

1000 UPCs, 40 EPCs each
6000 UPCs, 5  EPCs each

TPM 3/26/16 Update

I rewrote this and optimized it to write the EPCs as they are generated, with an autoreleasepool code block
to stop leaking memory, and it can now run indefinitely with an arbitrarily long list of input UPCs generating
as many EPC's as you'd like, if you have the time.  46000 UPCs, 1000 EPCs each took about an hour to run.

