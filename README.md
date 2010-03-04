# SEOChecker

Check your website if it is seo.

## Checklists

- use sitemap file
- each page are reachable
- each page has title
- use unique title tags for each page
- each page has meta description
- ues unique descriptions for each page
- url does not just use ID number.
- url does not use excessive keywords
- url does not have deep nesting of subdirectories

## Install

<code>sudo gem install seo_checker</code>

## Usage

It is easy to use, just one line.
<code>seo_checker http://example.com/</code>

It is strongly recommand to check seo in development environment. If you want to test in production environment, you can use option <code>--batch</code> and <code>--interval</code> to make sure it does not get too crowded.

<pre><code>
Usage: seo_checker [OPTIONS] website_url
    -b, --batch BATCH_SIZE           get a batch size of pages
    -i, --interval INTERVAL_TIME     interval time between two batches
        --debug
    -h, --help                       Show this message
</code></pre>

For example:

<pre><code>seo_checker http://localhost:3000</code></pre>

<pre><code>seo_checker http://yoursite.com --debug -b 10 -i 1</code></pre>
