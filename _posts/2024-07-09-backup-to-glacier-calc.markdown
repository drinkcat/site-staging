---
layout: post
title:  "AWS S3 Glacier Deep Archive Cost computation"
date: 2024-07-09 21:20:45+08:00
last_modified_at: 2024-07-15 12:10:42+08:00
categories: backup
---

There are a bunch of online articles/reddit posts that explain pricing,
but I'll redo the computation here, based on S3 [calculator](https://calculator.aws/#/createCalculator/S3) and my understanding.

**Update (July 15, 2024)**: Increased recommended average size from 128MB
to 256 MB, taking into account multipart upload cost.

First, you need to chose your zone carefully. `us-east-1` (N. Virginia)
seems to be [cheapest](https://aws.amazon.com/s3/pricing/). I do not care
too much about locality as I only plan to backup and restore fairly
infrequently.

The cost of storage, backup, and restore operations depends a lot
on the average file size. I found that keeping the average size above
256 MB is a good tradeoff (lower overhead cost, while allowing finer
grain restore operations).

It goes without saying this is provided without guarantee, please
double check my numbers.

### Storage cost

To quote the [pricing](https://aws.amazon.com/s3/pricing/) page:

> For each object that is stored in the [...] S3 Glacier Deep Archive
> storage classes, AWS charges for 40 KB of for index and metadata
> with 8 KB charged at S3 Standard rates and 32 KB charged at [...]
> S3 Deep Archive rates.

For example, to store 1 TB, with an average file size of 1 MB, the storage cost per month will look like this:

- Number of files: 1 TB / 1 MB = 1048576
- Actual S3 Glacier Deep data: 1 TB * $0.00099 / GB = $1.01376
- S3 Glacier Deep overhead: 1048576 \* 32 KB \* $0.00099 / GB = $0.03168
- S3 Standard overhead: 1048576 \* 8 KB \* $0.023 / GB = 0.184$
- Total cost: $1.23 / TB / month

From around 128MB, the overhead cost becomes totally negligible.

<div><canvas id="storageChart"></canvas></div>

### Backup cost (upload)

Backing up the data also comes at a cost, due to the cost of `PUT`
operations. As usual with cloud providers, ingress bandwidth is free.

For example, for 1 TB of 128 MB files:

- Number of files: 1 TB / 128 MB = 8192.
- Operation cost: 8192 * $0.05 / 1000 requests = $0.41 / TB
- Bandwidth cost: 1 TB * $0 / GB = $0
- Total cost: $0.41 / TB

This is where using big files saves a lot. 1 MB files would cost a
whopping $52.43/TB to upload.

<div><canvas id="backupChart"></canvas></div>

#### Multipart upload *(added July 15, 2024)*

There's one more thing to consider. To speed up the upload process,
it is common to upload using multiple connections and upload files
in chunks.

Multipart upload is [documented here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html). We can ignore the cost of storing
multipart parts during the operations (that would be short), but the
operations cost is still significant:

> Both CreateMultipartUpload and UploadPart are billed at S3 Standard rates
> [...] with only the CompleteMultipartUpload request charged at S3 Glacier > Deep Archive rates.

The default boto3 [transfer configuration](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/customizations/s3.html#boto3.s3.transfer.TransferConfig)
will upload the data in chunks of 8 MB. In this case (1 TB of 128MB files again):

- Number of files: 1 TB / 128 MB = 8192.
- Number of chunks: 1TB / 8 MB = 131072
- Operations: 8192 * $0.005 / 1000 = $0.041 / TB (CreateMultipartUpload, 1/file)
- Operations: 131072 * $0.005 / 1000 = $0.66 / TB (UploadPart, 1/chunk)
- Operations: 8192 * $0.05 / 1000 = $0.41 / TB (CompleteMultipartUpload, 1/file)
- Bandwidth: 1 TB * $0 / GB = $0
- Total cost = $1.11 / TB

This is a significantly increased cost.

If I want to stay near the default number of connection (10), I need at
least 8 chunks per file:

- 128 MB files, 16MB chunks: $0.78 / TB
- 256 MB files, 32MB chunks: $0.39 / TB
- 512 MB files, 64MB chunks: $0.19 / TB
- 1 GB files, 64MB chunks: $0.097 / TB

I think 256MB is a good tradeoff (less than half a month of storage cost
to upload the data).

<div><canvas id="backupChunkChart"></canvas></div>

### Restore cost (download)

Restoring the data also cost money. The first step will be to retrieve
the object from "Deep Glacier" to "Standard".

There are 2 retrieval options: Standard and Bulk. Standard is much
more expensive (~10x), but faster (12h vs 48h)

The web UI (and also the API) allows you to select how many days to keep
the data in Standard storage, which you will be charged for. Of course,
you need to set a long enough number of days so that you have time to
download the data.

![Image]({{"/images/restore.png" | relative_url }})
*AWS Web UI restore interface*

Also, egress bandwidth is charged, but the first 100GB/month are free,
so if you only restore a small amount of data, or if you willing to wait
many months, costs can be limited.

For example, for 1 TB of 128 MB files:

- Number of files: 1 TB / 128 MB = 8192.
- Retrieval cost/operation: 8192 * $0.025 / 1000 requests = $0.20 / TB
- Retrieval cost/GB: 1 TB * $0.0025 / GB = $2.56 / TB
- S3 standard storage cost (7 days): 1 TB * $0.023 / GB * 7/30 = $5.50 / TB
- Bandwidth cost: 1 TB * $0.09 / GB = $92.16
- Total cost: $100.42 / TB
  - Total cost for the first 100 GB: $0.81 / 100 GB (no bandwidth cost)

Here, the cost is heavily dominated by the egress bandwidth cost, if one
can keep under the 100GB / month bandwidth, the price becomes a lot more
interesting.

Standard restore is about 4 times pricier if bandwidth does not need to
be paid for. If not, it's only a smaller 20% price increase.

Assuming no bandwidth cost, restoring a single 128MB file costs 0.001$ with
Bulk restore, and 0.004$ with Standard restore: if only a few files need to
be restored the costs are negligible anyway and there is no reason to use the slower Bulk restore.

<div><canvas id="restoreChart"></canvas></div>

### Calculator

Again, it goes without saying this is provided without guarantee, please
double check my numbers.

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<script>
var resultElement;
var charts = [];

document.addEventListener("DOMContentLoaded", function(event){
  var xpath = "//code[contains(text(),'__CALCULATOR_OUTPUT__')]";
  resultElement = document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
  compute()
})

// Round price to cents
function price(x) {
  if (x > 0.1)
    scale = 100
  else
    scale = 10**(-Math.floor(Math.log10(x))+2)
  return Math.round(x*scale)/scale
}

function compute() {
  filesize = parseFloat(document.getElementById('calc_filesize').value)
  chunksize = parseFloat(document.getElementById('calc_chunksize').value)
  compute2(filesize, chunksize, true)

  bw_free = parseFloat(document.getElementById('calc_bw_free').value)

  size = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
  sizelabels = size.map(x => (x > 1000) ? Math.floor(x / 1024) + " GB" : x + " MB")
  chunksizes = [0, 8, 16, 32, 64, 128]
  upload_data_labels = chunksizes.map(x => "Backup cost $/TB (" + x + " MB chunks)")
  upload_data_labels[0] = "Backup cost $/TB (no multipart upload)"

  storage_data = []
  upload_data= chunksizes.map(x => [])
  download1_data = []
  download2_data = []
  download3_data = []
  download4_data = []

  for (i in size) {
    data = compute2(size[i], chunksize, false)
    storage_data[i] = data[0]
    download1_data[i] = data[2]
    download2_data[i] = data[3]
    download3_data[i] = data[4]
    download4_data[i] = data[5]
    for (j in chunksizes) {
      // Inefficient, we don't technically need to recompute all costs
      data = compute2(size[i], chunksizes[j], false)
      upload_data[j][i] = data[1]
    }
  }

  for (chart of charts) {
    chart.destroy()
  }
  charts[0] = genChart('storageChart', sizelabels, ['Storage cost $/TB/month'], [storage_data])
  charts[1] = genChart('backupChart', sizelabels, [upload_data_labels[0]], [upload_data[0]])
  k = 6 // Start from 64MB size for backupChunkChart.
  charts[2] = genChart('backupChunkChart', sizelabels.slice(k, -1), upload_data_labels, upload_data.map(x => x.slice(k, -1)))
  charts[3] = genChart('restoreChart', sizelabels,
      ['Bulk restore cost $/TB', `Bulk restore cost $/TB (< ${bw_free} GB/month)`,
       'Standard restore cost $/TB', `Standard restore cost $/TB (< ${bw_free} GB/month)`
      ],
      [download1_data, download2_data, download3_data, download4_data])
}

function genChart(element, xlabels, label, data) {
  const ctx = document.getElementById(element);
  const colors = [ 'rgb(75, 192, 192)', 'rgb(192, 75, 192)', 'rgb(192, 192, 75)', 'rgb(192, 75, 75)', 'rgb(75, 192, 75)', 'rgb(75, 75, 192)']
  datasets = []
  for (i in label) {
    datasets[i] = {
        label: label[i],
        data: data[i],
        fill: false,
        borderColor: colors[i],
        tension: 0.1
      }
  }
  return new Chart(ctx, {
    type: 'line',
    data: {
      labels: xlabels,
      datasets: datasets
    },
    options: {
        scales: {
            x: { title: { display : true, text: "Average file size" } },
            y: { title: { display : true, text: "USD" } }
        }
    }
  });
}

function compute2(filesize, chunksize, show) {
  if (show)
    resultElement.innerHTML = 'ERROR'
  s3std = parseFloat(document.getElementById('calc_s3std').value)
  s3deep = parseFloat(document.getElementById('calc_s3deep').value)
  put_op = parseFloat(document.getElementById('calc_put_op').value)
  put_op_std = parseFloat(document.getElementById('calc_put_op_std').value)
  ret_bulk_op = parseFloat(document.getElementById('calc_ret_bulk_op').value)
  ret_bulk_size = parseFloat(document.getElementById('calc_ret_bulk_size').value)
  ret_std_op = parseFloat(document.getElementById('calc_ret_std_op').value)
  ret_std_size = parseFloat(document.getElementById('calc_ret_std_size').value)
  bw = parseFloat(document.getElementById('calc_bw').value)
  bw_free = parseFloat(document.getElementById('calc_bw_free').value)

  nfiles = 1024*1024 / filesize; //(1TB/MB)
  nchunks = 1024*1024 / chunksize; //(1TB/MB)
  storage1 = 1024 * s3deep; // 1TB
  storage2 = nfiles * 32 * s3deep/1024/1024;
  storage3 = nfiles * 8 * s3std/1024/1024;
  upload1 = nfiles * put_op / 1000;
  if (chunksize == 0) {
    upload2 = 0
    upload3 = 0
  } else if (chunksize >= filesize && !show) {
    upload2 = NaN
    upload3 = NaN
  } else {
    upload2 = nfiles * put_op_std / 1000; //CreateMultipartUpload
    upload3 = nchunks * put_op_std / 1000;
  }
  download1 = nfiles * ret_bulk_op / 1000;
  download1s = nfiles * ret_std_op / 1000;
  download2 = 1024 * ret_bulk_size;
  download2s = 1024 * ret_std_size;
  download3 = 1024 * s3std * 7 / 30;
  download4 = 1024 * bw;

  if (show) {
    resultElement.innerHTML = ''
    resultElement.innerHTML += `- Number of files: 1 TB / ${filesize} MB = ${nfiles}\n`;
    resultElement.innerHTML += '\nStorage:\n';
    resultElement.innerHTML += `- Actual S3 Glacier Deep data: 1 TB * $${s3deep} / GB = $${price(storage1)} / TB\n`;
    resultElement.innerHTML += `- S3 Glacier Deep overhead: ${nfiles} * 32 KB * $${s3deep} / GB = $${price(storage2)} / TB\n`;
    resultElement.innerHTML += `- S3 Standard overhead: ${nfiles} * 8 KB * $${s3deep} / GB = $${price(storage3)} / TB\n`;
    resultElement.innerHTML += `- Total cost = $${price(storage1+storage2+storage3)} / TB / month\n`;

    resultElement.innerHTML += '\nBackup/upload:\n';
    if (chunksize == 0) {
      resultElement.innerHTML += `- Operations: ${nfiles} * $${put_op} / 1000 = $${price(upload1)} / TB\n`;
    } else {
      resultElement.innerHTML += `- Number of chunks: 1 TB / ${chunksize} MB = ${nchunks}\n`;
      resultElement.innerHTML += `- Parallel uploads: ${filesize} MB / ${chunksize} MB = ${filesize/chunksize}\n`;
      resultElement.innerHTML += `- Operations: ${nfiles} * $${put_op_std} / 1000 = $${price(upload2)} / TB (CreateMultipartUpload, 1/file)\n`;
      resultElement.innerHTML += `- Operations: ${nchunks} * $${put_op_std} / 1000 = $${price(upload3)} / TB (UploadPart, 1/chunk)\n`;
      resultElement.innerHTML += `- Operations: ${nfiles} * $${put_op} / 1000 = $${price(upload1)} / TB (CompleteMultipartUpload, 1/file)\n`;
    }
    resultElement.innerHTML += `- Bandwidth: 1 TB * $0 / GB = $0\n`;
    resultElement.innerHTML += `- Total cost = $${price(upload1+upload2+upload3)} / TB\n`;

    resultElement.innerHTML += '\nRestore/download:\n';
    resultElement.innerHTML += `- Retrieval operation (bulk): ${nfiles} * $${ret_bulk_op} / 1000 = $${price(download1)} / TB\n`;
    resultElement.innerHTML += `- Retrieval per GB (bulk): 1 TB * $${ret_bulk_size} / GB = $${price(download2)} / TB\n`;
    resultElement.innerHTML += `- S3 standard storage cost (7 days): 1 TB * $${s3std} / GB * 7 / 30 = $${price(download3)} / TB\n`;
    resultElement.innerHTML += `- Bandwidth cost: 1 TB * $${bw} / GB = $${price(download4)} / TB\n`;
    resultElement.innerHTML += `- Total cost = $${price(download1+download2+download3+download4)} / TB\n`;
    resultElement.innerHTML += `  - Total cost for the first ${bw_free} GB = $${price((download1+download2+download3)/1024*bw_free)} / ${bw_free} GB\n`;
  }
  return [storage1+storage2+storage3, upload1+upload2+upload3,
      download1+download2+download3+download4, download1+download2+download3,
      download1s+download2s+download3+download4, download1s+download2s+download3]
}
</script>

- Average file size: <input id="calc_filesize" size="4" value="256"/> MB
- Multipart upload chunk size: <input id="calc_chunksize" size="4" value="32"/> MB
- Cost (prefilled with us-east-1, N. Virgnia, as of July 2024)
  - S3 Standard: $<input id="calc_s3std" size="5" value="0.023"/>/GB/month
  - S3 Glacier Deep Archive: $<input id="calc_s3deep" size="5" value="0.00099"/>/GB/month
  - PUT, COPY, POST, LIST requests (Standard): $<input id="calc_put_op_std" size="5" value="0.005"/>/1000 operations
  - PUT, COPY, POST, LIST requests (Deep Archive): $<input id="calc_put_op" size="5" value="0.05"/>/1000 operations
  - Retrieval (Deep Archive, Bulk): $<input id="calc_ret_bulk_op" size="5" value="0.025"/>/1000 operations
  - Retrieval (Deep Archive, Bulk): $<input id="calc_ret_bulk_size" size="5" value="0.0025"/>/GB
  - Retrieval (Deep Archive, Standard): $<input id="calc_ret_std_op" size="5" value="0.10"/>/1000 operations
  - Retrieval (Deep Archive, Standard): $<input id="calc_ret_std_size" size="5" value="0.025"/>/GB
  - Bandwidth: $<input id="calc_bw" size="5" value="0.09"/>/GB
    - Free bandwidth: <input id="calc_bw_free" size="5" value="100"/> GB / month

<button type="button" onClick="compute()">Recompute</button>
(changing price also updates graphs above)

```
__CALCULATOR_OUTPUT__
```
