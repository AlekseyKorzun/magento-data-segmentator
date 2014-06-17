Magento Data Segmentator  (v1.0.1)
==========================

Magento data segmentation allows you to extract tailored sets of data from your Magento database.

Currently script supports data retrieval via customer email patterns and/or back log of (x) days. 

Tested against Magento EE 1.1x.x.

Requirments
-----
Out of the box the script needs to be executed on the same server that hosts your Magento database.

Since we do not handle authentication, you should create a new user with proper permissions
and setup authentication via .my.cnf file.

See: http://dev.mysql.com/doc/refman/5.1/en/option-files.html

Usage
-----

-s name of your Magento database schema
-e match customers email address, ex: -e '(generic.com|specific.email@domain.com)'
-d retrieve all customers registered within specified number of days
-l limit overall result to this number
-f name of generated data dump
-r raw mode, the script will output a non-compressed .sql dump

Examples
-----

Generate a database dump with customers that have @gmail.com email address:

```bash
segmentator.sh -s magento -e '@gmail.com' -f dump.magento.sql.gz
```

Now let's get a dump with customers that registered within last 7 days:

```bash
segmentator.sh -s magento -d 7 -f dump.magento.sql.gz
```

Get all customers that either have @gmail.com or @hotmail.com as an email address. 

On top of that we will retrieve all of the customers that registered within past 7 days and limit overall data set
to 1000 customers:

```bash
segmentator.sh -s magento -e '@gmail.com|@hotmail.com' -d 7 -l 1000 -f dump.magento.sql.gz
```

About
-----

See: http://tech.baublebar.com/magento-data-segmentator
