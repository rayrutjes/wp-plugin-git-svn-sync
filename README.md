## About this script

This opinionated script is about forgetting that you have to deal with SVN for publishing
your WordPress plugin to the [official repository](https://wordpress.org/).

It handles:

- Syncing your assets (only updates them if needed)
- Syncing your tags (only pushes tags that do not yet exist)
- Syncing your trunk (only updates if changes are detected)

## Basic usage

```bash
./sync.sh \
	--plugin-name="search-by-algolia-instant-relevant-results" \
	--git-repo="https://github.com/algolia/algoliasearch-wordpress" \
	--svn-user=algolia
```

This will sync your assets, push all tags that do not exist yet and update the trunk.

## Custom Assets Directory

By default, the script expects your assets to be in a directory named
`.wordpress.org` at the root of your Git repository.

You can customize this by providing a relative path to your assets directory:

```bash
./sync.sh \
	--plugin-name="search-by-algolia-instant-relevant-results" \
	--git-repo="https://github.com/algolia/algoliasearch-wordpress" \
	--svn-user=algolia
	--assets-dir="screenshots"
```

Here the script will push the assets from `your-git-root/screenshots` directory.

Note that the script will also always try to remove the assets-dir from the trunk
and tags releases.

## Exclude Files

To exclude files from synchronization, you just need to drop a file named
`.distignore` in the root of your Git repository.

This file should be formatted just like a .gitignore file.

Checkout an [example of `.distignore` file here](https://github.com/wp-cli/sample-plugin/blob/master/.distignore).

The script will then expand every line and exclude matching files from synchronization.

### Requirements

1. Your plugin must have been accepted, and you should have the plugin slug name.
1. Have a `.wordpress.org` directory containing the screenshots to be displayed
on the detail page on the plugin directory.
1. Have a master branch that contains the most up to date version of your plugin.
Your plugin files should be held at the root of the repository.
1. Tag your releases with Git if you want to push tags.
