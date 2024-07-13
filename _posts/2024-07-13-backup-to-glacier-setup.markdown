---
layout: post
title:  "AWS S3 setup for backups"
date: 2024-07-13 16:40:06+08:00
categories: backup
---

This post will go through details of how I setup AWS account and
S3 bucket for this use case, using the AWS web console.

Again, I'm not ane expert, but this seems to work for me and my use case.
I went through these steps manually in the Amazon web console UI, it's of
course possible to automate this. Maybe for another time.

### Budget

First of all, let's avoid disasters. The first thing I setup after creating
the AWS account is a budget with low values, so I get alerts in case I
accidentally use more storage than I planned to.

Under "Billing and Cost Management", I setup a Budget with the following
parameters: "Monthly", "Recurring budget", "Fixed", $1.00, for all
Amazon services.

I then setup 2 alerts, each for $0.01, one on "Actual" cost, and the
other on "Forecasted" cost, with my email as recipient.

The numbers are of course too low, the idea is to slowly increase those
when I get a good grasp on actual total costs.

Also note that, those are just alerts, and, at least to my understanding,
there is no way to set hard limits: you can totally blow through your
budget. Be careful, upload things slowly to make sure your computations
are correct.

### IAM identities

As root, I created 2 user accounts:

- One with console access and at least "AmazonS3FullAccess" permission
  ("interactive" user)
- Another *without* console access that I would use for a command line tool I'll describe in the future ("bot" user), also with "AmazonS3FullAccess".

You can then logout from the web console, and login again as the
"interactive" user.

### S3 bucket configuration

Now it's time to create a S3 storage bucket. Find the "S3" service in the
web console, and press "Create Bucket". Make sure you're in the correct zone
before starting (`us-east-1` is cheap). Pick a good name, you can't change
it. Default settings are reasonable: you want to create a "General purpose"
bucket, with "ACLs disabled" and "Block all public access" set.

I decided to enable Bucket Versioning, as an extra layer of safety. In
this mode, S3 will keep old versions of the files if they get overwritten or
deleted. However, you will still be charged for older versions of the
files, but there are rules you can setup to auto-expire non-current objects,
see below.

I left Encryption to the default (SSE-S3), and disabled object lock.

#### Lifecycle rules for versioned bucket

If you enabled bucket versioning, you probably want to create a lifecycle
rule to expire older versions of the objects. This can be done in
"Management" => "Create lifecycle rule":

Pick a good name like "delete-noncurrent", "Apply to all objects in the
bucket". As actions, pick "Permanently delete noncurrent versions of objects"
and "Delete expired object delete markers or incomplete multipart uploads".

For the first action ("Permanently delete"), I chose 7 days and 0 versions
(you can keep the field empty). For the second action ("multipart uploads"),
I ticked both boxes ("Delete expired object delete markers" and "Delete
incomplete multipart uploads"), again, with 7 days.

#### Storage lens

It's useful to look at the dashboard in Storage lens from time to time,
that's how I realized I had a bunch of non-current objects that I was being
charged for (but could be deleted).

For some reason, that cannot be accessed from the root user (only from
a normal user).

#### Email notifications for restore events

As restoring from Glacier takes 12-48h, it's useful to setup an email
notification when the data is ready.

First, go to "Simple Notification Service", create a new topic, "Standard",
then leave all the settings as default. In your topic, create a new "Email"
subscription with your email address, confirm it in the email your receive.

Then, back to S3, in your bucket, setup an "Event notification" for
"All restore object events", attach it to the "SNS Topic" that you just
created.

The email notifications are not-so-pretty JSON-formatted, but at least you
get informed when restoration is complete.
