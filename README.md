# AIDS Walk Team Fundraising Scraper

A toy project that periodically scrapes [AIDS Walk Wisconsin](https://www.aidswalk.net/wisconsin/) fundraising data for a team and notifies you of your standing within it.

This code does what it needs to do. That doesn't include being taken very seriously.

## What Is It?

Broadly speaking, there are three things that the code in this repo does:

1. Scrape a team's fundraising data, returning a list of team members and the amounts they've raised in descending order by amount.
1. Store data from each scrape in a database, so you can Have Fun With It later.
1. Send an email telling you how much you've raised and where you are in the standings.

Each of these features is implemented within an [AWS Lambda](https://aws.amazon.com/lambda/) function.

This project also defines the infrastructure for deploying these functions to AWS.
[Terraform](https://www.terraform.io) is our infrastructure provisioning tool of choice.

Beyond Lambda, this project is almost entirely dependent on AWS services.
It uses [DynamoDB](https://aws.amazon.com/dynamodb/) as its database solution (not that its use cases are really exercising it) and [Simple Email Service](https://aws.amazon.com/ses/) to send notifications.
You will need to [verify](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-email-addresses.html) any email addresses you use.

## Project Structure

This project is largely divided into four top-level directories:

- `script/` includes the initialization and deployment scripts you'll need to work with the project.
    - [`script/init.sh`](script/init.sh) is the first thing you'll want to run to set up a development environment.
      It will install the development dependencies and seed a [`.tfvars` file](https://www.terraform.io/docs/language/values/variables.html#variable-definitions-tfvars-files) that you can use for testing.
    - [`script/package.sh`](script/package.sh) will create a `.zip` artifact for the Lambda functions. 
      You can execute this yourself, or you can call it indirectly `script/build-and-deploy.sh`
    - [`script/build-and-deploy.sh`](script/build-and-deploy.sh) will, when given the name of an infrastructure deployment (`test` or `prod`), refresh the Lambda function artifact and redeploy the infrastructure.
- `src/` includes the code for the Lambda function handlers.
- `tests/` includes the (basic!) unit tests for the handlers.
  These are not included in the build artifact.
- `infra/` includes the Terraform infrastructure definitions for "test" and "prod" stacks.
  These both rely on shared infrastructure modules, and are separated from each other largely to make it easy to maintain state separately.
  
## Getting Started

### Requirements

- Python 3.8
- Terraform 0.15.3 (specified in [`.terraform-version`](.terraform-version) for use with [tfenv](https://github.com/tfutils/tfenv#terraform-version-file))

### Command Overview

To set the project up for local development:

```shell
$ script/init.sh
```

To run the tests:

```shell
$ pytest
```

To update the [test snapshots](https://pypi.org/project/pytest-snapshot/):

```shell
$ pytest --snapshot-update
```

To deploy test infrastructure:

```shell
$ script/build-and-deploy.sh test
```

To deploy production infrastructure:

```shell
$ script/build-and-deploy.sh prod
```

### Customizing The Infrastructure

The infrastructure deployments are parameterized by a few settings that most deployments would want to change.
These are given in the [production](infra/prod/main.tf) and [test](infra/test/main.tf) infrastructure definitions.

To get you started, the test infrastructure has an [example `terraform.tfvars` file](infra/test/terraform.tfvars.example).
[`script/init.sh`](script/init.sh) will copy this to `infra/test/terraform.tfvars` for you to edit.

### Development And Production Dependencies

This project contains two [Pip requirements files](https://pip.pypa.io/en/stable/user_guide/#requirements-files):

- [`requirements.txt`](requirements.txt) defines the dependencies that are needed to run the application code on AWS Lambda infrastructure
- [`requirements-dev.txt`](requirements-dev.txt) defines the dependencies that are needed to develop and test the application locally

If you use an IDE, you will likely need to configure it to use `requirements-dev.txt` as your requirements file to have proper navigation and autocompletion.
For example, you can find instructions for how to do this in PyCharm [here](https://www.jetbrains.com/help/pycharm/managing-dependencies.html#configure-requirements).

## A Brief Word About Tradeoffs

This project is not designed to or expected to last very long.
This impacts most of the engineering decisions:

- AWS Terraform providers are used directly with little to no abstraction.
- The unit tests are relatively sparse, mostly serving to flag accidental regressions during local refactoring.
  The project was _not_ created with test-driven development.
- The Python source code is not modularized or packaged into separate artifacts for each Lambda function.
- There is no infrastructure definition for a deployment pipeline.

## License

[3-Clause BSD License](LICENSE)
