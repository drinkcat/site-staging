---
layout: post
title:  "A simple tool to upload photos in archives"
date: 2024-08-15 11:10:52+08:00
categories: backup
---

This post will go through a simple tool, called [**simple-serac**](https://github.com/drinkcat/simple-serac),
I built to upload photos (or any other big files) to Glacier.

**simple-serac** is available on [github](https://github.com/drinkcat/simple-serac), under a BSD license.

I'll just repeat the design philosophy here, we'll go through a
concrete use case in the next post.

### Philosophy

- Targets **infrequent backups** of relatively **large files** (~megabytes), e.g. a photo library.
  - Assumes you have enough RAM to keep the list of all files in memory (this shouldn't be a problem unless you have millions of files).
  - Do not use this to backup small files, e.g. your home directory. Use more suited tools like [duplicity](https://duplicity.us/).
  - Only knows how to backup normal files and symbolic links.
- Targets Amazon S3 Deep **Glacier**: Cost of restoring many objects can be very expensive, so we bundle the files in relatively large tarball chunks (256 MiB by default).
  - Relatively small chunks make it reasonably cheap to restore a single file if needed.
  - Most chunks will be somewhat larger than the set limit, as a single file will never stride over multiple chunks.
- Only supports **incremental backups**: new and modified files are uploaded. No awareness of deleted files.
  - If you want to start a new full backup, chose a different bucket or directory.
- **Simple, human readable database**: restoring is possible without special tools.
- Not meant to be used unattended: Will not remove anything on the remote side, will bail out on most errors, **may require human intervention**.
- Can be interrupted and restarted without loss.

### Design

The S3 bucket directory contains 3 subdirectories:

- **Database**: `db/*.json` (in AWS `STANDARD` storage)
- **Data**: `data/*.tar` (in AWS `GLACIER` storage)
- **Reports**: `reports/*.csv` (in AWS `STANDARD` storage)

#### Database

The database is a set of `json` files in `db/`. Each tarball in `data/` has a corresponding database file, listing the content in the tarball.

We need this database in `STANDARD` storage, so that it's readily, and cheaply, available for restore operations, or for incremental backups.

For example, `db/20240706-114654-000337.tar` (a tarball of ~128MB) has a corresponding json database file `db/20240706-114654-000337.json`, listing the 101 files within it.

For each file in the tarball, we save the name, size, modified time, and SHA-256. For example:

```json
    {
        "name": "ALL_PHOTOS/2018/05/20180520_124950.jpg",
        "size": 390633,
        "modified": "2018-05-20T04:49:50+00:00",
        "sha": "c977fc1f2e2bd371480c625d3e5564716b8921ccf879712f679a2cd1b07ee0d9"
    },
```

#### Reports

While the json files are technically human-readable, finding a target file in them would be a bit difficult: There can be hundreds of them, and the content is not terribly easy to `grep`.

Therefore, at the end of the backup process, the tool creates a `.csv` report in `reports/` that can be imported into a spreadsheet app if needed for easier visualization.

Only the last report needs to be downloaded: it aggregates data from all incremental backups.

#### Runtime

At runtime, the tool does the following:

- Connect to S3.
- Run some basic sanity check on the remote directory structure.
- Fetch the database to a local directory in `.cache` (only copies the files if they are not already present).
- Read and parse the database.
- List all files in the local directory:
  - For each file, see if there is already and entry in the database, if so, compute the SHA-256. If the file is new, or the SHA-256 differs, mark the file for upload.
  - Once the size of the files marked for upload exceeds the chunk size (256 MiB):
    - Generate a tarball named `YYYYMMDD-HHMMSS-0000iii.tar` (date, time, and an increasing index `i`) and upload the tarball to S3.
    - Generate the database file `YYYYMMDD-HHMMSS-0000iii.json` and upload it.
      - (We do it in this order as a lone tarball without corresponding database would have no impact apart from a little bit of lost storage.)
    - Continue processing files.
- Generate a report `csv` file and upload it to S3.
