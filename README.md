# GeniTag
EPC generator

Use this app to generate EPC encodings for performance testing.  It can encode DPCI's in a GID, or UPC barcodes
in an SGTIN.

Note: The input file should be a csv containing barcodes to be encoded.  You are limited by memory as to how
many you can create on a single run.  It has been shown that for 1000 barcodes, you can generate up to 40 EPCs
per barcode per run.  Each run's output file will have the number of EPCs appended to the output file name. 
