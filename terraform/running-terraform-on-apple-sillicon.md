[According to
Hashicorp](https://discuss.hashicorp.com/t/template-v2-2-0-does-not-have-a-package-available-mac-m1/35099),
the Template provider called out in our scripts was deprecated
before the Apple M1 (`darwin_arm64`) releases came out. If you see
this error:

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 3.0"...
- Finding latest version of hashicorp/template...
- Installing hashicorp/aws v3.75.1...
- Installed hashicorp/aws v3.75.1 (signed by HashiCorp)
╷
│ Error: Incompatible provider version
│
│ Provider registry.terraform.io/hashicorp/template v2.2.0 does not have a package available for your current
│ platform, darwin_arm64.
│
│ Provider releases are separate from Terraform CLI releases, so not all providers are available for all
│ platforms. Other versions of this provider may have different platforms supported.
```

It's because there is no direct support for M1.

Hashicorp recommends using [Rosetta](https://support.apple.com/en-us/HT211861) to emulate amd64 architecture for Terraform. You could also build Terraform from code and install it manually; those steps aren't covered here.

We used the following workaround instead:

1. Remove any terraform binaries in your `PATH`. If you have it installed multiple times, use
   `which terraform` to find and remove each reference.

1. Install this [provider helper](https://github.com/kreuzwerker/m1-terraform-provider-helper) using Homebrew:

```
brew install kreuzwerker/taps/m1-terraform-provider-helper
```

1. Then (re)install Terraform

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

1. Now install the hashicorp/template version v2.2.0

```
m1-terraform-provider-helper install hashicorp/template -v v2.2.0
```

1. Check the active version

```
terraform --version
```

1. Return to the cloud directory you are using and try the `terraform init` command.
