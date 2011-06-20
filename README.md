**Dew** is an environment management tool intended for use in multi-instance AWS application deployments.

It's called **dew** as it's a layer under [Fog](http://fog.io) which in turn is a layer under various cloud platforms.

It includes:

  * one command `dew`, with subcommands eg. `environments`, `amis`
  
These subcommands can:

  * create and destroy **environments**, a collection of AWS instances, a load balancer and a database
  * create and destroy **amis**, machine images used to create instances in your environments
  * configure your **amis** with [Puppet](http://www.puppetlabs.com)
  * deploy MRI Passenger and JRuby Tomcat applications to your **environments**

This code is Open Source, but some of it is still specific to PlayUp. Running `cucumber` with a correctly configured `development.yaml` will drain whichever credit card you've attached to that account!

## Getting Started

    $ [sudo] gem install dew

### If you're an employee of PlayUp:

    $ git clone git@github.com:playup/dew-config.git ~/.dew

### Otherwise:

#### 1. Copy over the example configuration and edit the default account file

    $ cp -r `gem which dew | dirname`/../../example/dew ~/.dew
    $ vi ~/.dew/accounts/development.yaml
    
Replace the `user_id`, `access_key_id` and `secret_access_key` with your AWS credentials.

#### 2. Install your keypair

Either pick an existing keypair or create a new one. You'll need to do this once for each account and region you intend to operate in.

Place the `.pem` file in the following location:

    ~/.dew/accounts/keys/$ACCOUNT/$REGION/$KEYPAIRNAME.pem
    
For example, the `.pem` file for the `default` key in `development` account and in the `ap-southeast-1` region would go in:

    ~/.dew/accounts/keys/development/ap-southeast-1/default.pem

Don't worry about setting permissions for the key - **dew** will manage that itself.

#### 3. Configure your security groups

**dew** makes a couple of assumptions about how you've set up your security groups. Unfortunately, **dew** doesn't yet possess the capability to manage this for you:

  * it expects that the `default` security group allows for SSH from the host you're creating the environment from
  * it expects that the `default` security group in your RDS configuration allows connections from your AWS account's instances

### Finally:

    $ dew --help
    
And perform a basic self-test:

    $ dew environments

## Creating a Simple Environment

## Creating an AMI for a new Environment

## Deploying to an Environment

## Developing with Dew

Read `HACKING.md`
