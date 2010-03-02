# SEOChecker

Check your website if it is seo.

## Checklists

- use sitemap file
- use unique title tags for each page
- ues unique descriptions for each page
- url does not just use ID number.
- url does not use excessive keywords
- url does not have deep nesting of subdirectories

## Usage

It is easy to use, just one line.
<code>seo_checker http://example.com/</code>

It is strongly recommand to check seo in development environment. If you want to test in production environment, you can use option <code>--batch</code> and <code>--interval</code> to make sure it does not get too crowded.

<pre><code>
Usage: seo_checker [OPTIONS] website_url
    -b, --batch BATCH_SIZE           get a batch size of pages
    -i, --interval INTERVAL_TIME     interval time between two batches
    -h, --help                       Show this message
</code></pre>

