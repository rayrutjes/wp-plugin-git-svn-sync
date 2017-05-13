## WordPress Plugin Git <-> SVN Sync. Script

In a world of Git, it is hard to keep SVN repository up to date.

Yet, to publish your WordPress plugin on the official [plugins directory](https://wordpress.org/),
you will need to master SVN.

This bash script will help you synchronize your plugin Git repository with the WordPress SVN repository seamlessly.

This is an opinionated script that will always try to push "assets", "tags and the "trunk".

## Usage

```bash
./sync.sh \
	--plugin-name="search-by-algolia-instant-relevant-results" \
	--git-repo="https://github.com/algolia/algoliasearch-wordpress" \
	--svn-user=algolia
```

Note that you can run this script at any point in time.

## How it works

### Requirements

1. Have an "assets" directory containing the screenshots to be displayed
on the detail page on the plugin directory
(this folder will be removed from trunk and tag releases)
1. Have a master branch that contains the most up to date version of your plugin.
Your plugin files should be held at the root of the repository.
1. You must tag releases in your Git repository prior to running this script.


### Assets

It copies over the `assets` folder at the root of your Git repository.

**Note that because of this convention, we also remove the `assets` folder from the tags and trunk files.**

We take care of setting the proper mime types for jpg and png images in SVN.

### Tags

It gets the tags from the Git repository, and pushes all tags that are not yet present on SVN repository.


### Trunk

This pushes your **Git master branch** as the SVN trunk.
