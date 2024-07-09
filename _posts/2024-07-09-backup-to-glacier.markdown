---
layout: post
title:  "Backup to AWS S3 Glacier Deep Archive"
date: 2024-07-09 20:51:35+08:00
categories: backup
---
While figuring out my personal backup story, handling old hard drives
that miraculously still spin up after 10 years of storage, I decided
to do some research on Glacier storage. I'm not at all an expert
in the area, but I thought I'd write this up, if only as a summary
for my future self.

### Rationale

A lot of the data I'd like to backup is fairly old, and in all
likelihood I'll never want to restore it.

I'd also like to become better at disaster recovery, by semi-regularly
backing up Google-backed content (Drive, gmail, etc.), to protect
against unlikely cases of account theft or lockdown, and generally
increase redundancy.

Photos storage is another complicated case, and the main reason I
started looking into this. I store all of my pictures and videos
in Google Photos. However, size keeps creeping up, and at some
point I'll need to buy more and more storage for them. It's handy
to be able to search through old photos, but truth is, I almost
never need the highest possible resolution. I would be fine with keeping
a lower resolution copy (e.g. "[Storage Saver](https://support.google.com/photos/answer/6220791?hl=en&co=GENIE.Platform%3DAndroid#zippy=%2Cexpress)")
in Google photos, as long as I have a backup of the higher resolution picture somewhere. I'll go through this use case in a future article.

Storing backups to (multiple) external hard drive is fine, and I did
that _as well_, but it would be nice to have a secondary copy in the
cloud in case of disaster (say, fire, flood, theft, or if an issue
happens during extended travel, where I do not have my hard drives
with me).

### Amazon S3 Glacier

This is where cloud "Glacier" storage kicks in. Basically, this is
a cheap class of storage class for rarely fetched files.

Cost-wise, Google Drive is about 10 USD/month for 2TB, but you pay
that amount regardless of actual usage, and you have to jump to a
much pricier plan if you go above 2TB. I also wanted to spread data
over multiple providers, so this is not a great option.

"Normal" Amazon S3 storage [costs](https://aws.amazon.com/s3/pricing/)
about 23 USD/month/TB (us-east), charged on what you use only.

"Glacier Deep Archive" is about 1 USD/month/TB, so that's about 5-20
time cheaper than alternatives. (note: I believe Microsoft Azure has a
similar product, similarly priced -- I do not believe Google Cloud does)

That comes with a bunch of caveats though:

- Restore process takes 12-48 hours. That's ok for my use case, I'd
  only infrequently access the data.
- Storing and restoring small files can be very expensive. It is much
  cheaper to store large objects (e.g. larger than 128MB on average).
  I'll need to figure out a system to store photos.
- Unlike Google Drive, operations are charged. In particular, egress
  bandwidth from cloud to Internet, during restore operations, is fairly
  expensive, and dominates the costs (ingress is free).
  - Overall, it very cheap to upload to storage (~1 USD/TB for large
    files).
  - Downloading is pricy (~100 USD/TB), due to bandwidth charges.
    However, Amazon gives you 100 GB of bandwidth per month for free.
    If you one can stay under that, restoring can cost less than 1 USD
    for those 100 GB.
    - This is also ok for me. I'm ok to pay the price in case of a
      serious disaster, while being able to fetch a good number of files
      for a cheap price.
- Files deleted before 180 days still get charged for 180 days. Fine by
  me.

In the [next post]({% link _posts/2024-07-09-backup-to-glacier-calc.markdown %}),
I'll go through the details of costs (storage, backup, and restore).
