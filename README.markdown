# Biola Deploy

## Description
A collection of rake tasks to facilitate deployment of Biola's Ruby apps to it's own servers using [whiskey_disk](https://github.com/flogic/whiskey_disk).

## Usage

    wd setup --to=staging --path=/path/to/deploy.yml
    wd deploy --to=staging --path=/path/to/deploy.yml

Whiskey Disk will automatically run rake `deploy:post_setup` and `rake deploy:post_deploy`.

## Environment Variables

These environment variables should be defined under `rake_env` in your `deploy.yml` file.

* __RAILS\_ENV__  
  staging or production

* __RAILS\_RELATIVE\_URL\_ROOT__  
  `/base-path` if not running with it's own domain

* __APP\_NAME__  
  A lower case underscored name of the app to be used for usernames directories, etc.

* __APP\_URL__  
  The URL that will be used to access the site

* __WEB\_ROOT__
  The directory that all of your apps reside within

* __DB\_CREATE\_USERNAME__  
  Username of a privileged database user that can grant privileges and create databases and users

* __DB\_CREATE\_PASSWORD__
  Password for the privileged database user