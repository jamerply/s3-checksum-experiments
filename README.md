# S3 Checksum Experiements

A test program written in Ruby for uploading an object to S3 and comparing the S3-calculated
SHA256 checksum with a locally-calculated checksum.


## Requirements

`dd`: 9.6+
`ruby`: 3.2+
AWS Credentials configured using `aws configure`, environment variables, or other method

## Getting started

Create a random test file

```
$ dd if=/dev/urandom of=test-4m.dat bs=1M count=4
4+0 records in
4+0 records out
4194304 bytes (4.2 MB, 4.0 MiB) copied, 0.0110548 s, 379 MB/s
```

Install the Ruby S3 SDK

```
$ bundle install
```

Upload the test file to an S3 bucket

```
$ ./upload_file.rb {{ bucket_name }} {{ object key }} test-4m.dat 
File test-4m.dat successfully uploaded to {{ bucket_name }}:{{ object_key }}.
Upload completed in 1.49 seconds.
Comparing checksums...
Checksums match!
Checksum: 59eb5f5ed2e1070c4b8c44f10b79ca789779dceb30b2eda85ef1582ae0c78a54
```

## Notes

- By default, if you upload a file over 100 MiB, the checksum comparison will fail.
This behavior is expected and is part of what this script is intended to
demonstrate.

- This script is crude and is not intended for any production use.
