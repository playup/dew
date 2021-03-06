# TODO

## 2011-07-18

 * Instances get tagged with their username by 'environment', which 'server' model depends on - law of demeter violation.
 * Add username support to tests
 * Add username verbosity to scripts
 
## 2011-07-03

 * Add support for automated DNS setup (eg, provisioning an environment will set A records)
 * Add .dew/config support
 * Finish writing HOWTOs in README.md
 * Migrate Ash's documentation (formerly in doc/*)

## 2011-06-30
 * Figure out a better way to deal with NameVirtualHost in deployment
 * Fix origin/<branch> hack in deploy
 * Don't assume that we're grabbing passenger git repos from playup: configure in .dew/config instead
 * `--no-passenger` on `deploy passenger` is a hack, rework
 
## 2011-06-27

 * Add option to print ssh .config credentials as well as cli credentials

## 2011-06-14

* Reduce code duplication in `Inform`, allow debug/warning messages to support blocks

## 2011-06-10

* Move playup specific documentation in to dewconfig moduel

## 2011-06-09

* Clean up `environment_spec.rb` tests

## 2011-06-08

* Move confirmation / printing logic from out of the controllers and models and in to the commands
* Make an AMI model
* Make an ELB model
* Move `rds_authorized_ec2_owner_ids` from out of `Cloud`
* Move `valid_servers` from out of `Cloud`
* Turn puge deployment mechanism in to a generic tomcat deployment mechanism
* Remove script stuff in puge deploy class, have it run commands directly instead
* Rework passenger deployment into a controller
* Move code from deployment model into deployment controller
* Ensure documentation in `doc/` is up to date with the current gem mechanism
* Write HOWTO documentation for the following tasks:
  * Creating an AMI from an existing puppet configuration
  * Creating an environment from an AMI
  * Deploying a passenger application to that environment
* Reduce does/doesn't exist duplication in `amis_controller_spec.rb`
