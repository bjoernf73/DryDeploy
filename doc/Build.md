# Build.json

## Concept
The Build.json file contains the `build` object.  

The `build` is in essence a 2-ply scheme, or receipe, of how to build a module: 
1. In ply 1, the `order`, within `role`, specifies the order in which different types of *Roles*, will be deployed. A `role` may be a Windows domain controller, a Linux ProGet-server, an Azure Tenant, or any other type of resource, *configured in a specific way*. 

1. In ply 2, the `order`, within each `action` specifies the order in which specific types of actions are executed in order to *provision and configure* each `role` into a *ready-to-use-state*. Instantiated, the instance of the `role` is now a `resource`. An `action` may be to *clone a vSphere VM-template*, to *apply this DSC-configuration*, to execute *this Packer null-provider-configuration*, and so on.

```json
"build":
   {
        "order_type": "role",
        "roles": 
        [ 
           { "role": "dc-domctrl-froot","order": 1,"actions": 
                [    
                   {  "action": "terra.run",   "order": 1 },
                   {  "action": "dsc.run",     "order": 2 }
                ]
            },
           { "role": "dc-domctrl-add", "order": 2,"actions": 
                [
                   {  "action": "terra.run",   "order": 1 }, 
                   {  "action": "dsc.run",     "order": 2 }
                ]
            },
           { "role": "ca-certauth-root","order": 3,"actions": 
                [
                   {  "action": "terra.run",   "order": 1 },
                   {  "action": "dsc.run",     "order": 2 }
                ]
            }
        ]	
    }
}

```

### Build vs Resources
The `build` is part of the ModuleConfig, and it does not specify *instances of roles*, it specifies only a *build*. In the example above, the role *dc-domctrl-froot* is the first type of resource (`"order": 1`) to be deployed. The Role *dc-domctrl-add* is the second type of resource (`"order": 2`) to be deployed, and so on. 

To build, or *instantiate*, a module, you need an *EnvConfig*. The EnvConfig specifies values for your environment, and the specific instances of roles - resources - you want in your implementation of the system module. 

You may want one, or a couple, or more instances of the *dc-domctrl-add* at each site in your environment. The `build` of a module does not say how many, it just specifies that an instance of the *dc-domctrl-froot* will be deployed before any instances of the *dc-domctrl-add*. All instances of the *dc-domctrl-add* role will be deployed, according to the build, *after* any instance of *dc-domctrl-froot*. Then any instances of the *ca-certauth-root*, with order 3 (`{ "order": 3 }`) will be deployed. However, the framework contains a few other concepts that enables more complex deployment scenarios that will be explained below.

### `order_type`
The `build` has an `order_type` property with a value of `role` or `site`.
 
```json 
"order_type": "role"
```
When `"order_type": "role"`, the build will be followed regardless of the site the resource belongs to. So given that you've specified resources of the role *dc-domctrl-add* at site S1, S2 and S3, all those instances will be deployed before the role with `"order": 3`, the *ca-certauth-root*.

```json
"order_type": "site"
```
When `"order_type": "site"`, all instances belonging to the first site (defined in EnvConfig's `network.sites`), say site S1, will be tried deployed before any instances at the second site, say site S2, and so on. Within the site, the build order will be followed, meaning that if there are only instances at a single site, the value of `order_type` makes no difference. 


### `depends_on`
An `action` may depend on another action using the `depends_on` property. Consider the build below.
```json
"build":
   {
        "order_type": "role",
        "roles": 
        [
           { "role": "ca-certauth-root","order": 1,  "actions": 
                [
                   { "action": "terra.run",  "order": 1, "description": "Clones vSphere template + OS Customization" },
                   { "action": "dsc.run",    "order": 2, "description": "Downloads CertReq, signes and issuses Sub CA cert",
                        "depends_on":{ 
                            "role": "ca.cert-auth.issuing",
                            "dependency_type": "every",
                            "action": "dsc.run",
                            "phase": 1}},
                   { "action": "win.reboot", "order": 3, "description": "Restarts computer and waits until ready",
                        "depends_on":{ "dependency_type": "chained" }}
                ]
            },
           { "role": "ca-certauth-issuing", "order": 2, "actions": 
                [
                   { "action": "terra.run", "order": 1,             "description": "Clones vSphere template + OS Customization"    },
                   { "action": "dsc.run",   "order": 2, "phase": 1, "description": "Deploys Enterprise SubCA features and CertReq" },
                   { "action": "dsc.run",   "order": 3, "phase": 2, "description": "Fetches signed CA cert and configures CA"      },    
            ...]
            }
        ]
    }
```
The second Action (`"order": 2`) of role *ca-certauth-root* has the following `depends_on` configuration: 
```json
{ "action": "dsc.run",    "order": 2, "description": "Downloads CertReq, signes and issuses Sub CA cert",
    "depends_on":{ 
        "role": "ca.cert-auth.issuing",
        "dependency_type": "every",
        "action": "dsc.run",
        "phase": 1}},
...
```

This forces that `action` to be delayed, and multiplied, in the plan, scheduling it after every occurance (`"dependency_type": "every"`) of the dependency action. The `dependency_type` must have a value of `first`, `last` or `every`. If `"dependency_type": "first"`, the `action` will only be executed after the first occurrance of the dependency action. If `"dependency_type": "last"`, the `action` will only be executed after the last occurrance of the dependency action. If `"dependency_type": "every"`, the `action` will be executed after every occurrance of the dependency action.  

Note also the Action than follows immediately after, the Action with `"order": 3`: 
```json
{
    "action": "win.reboot",
    "description": "Restarts computer and waits until ready",
    "order": 3,
    "depends_on": 
   {
        "dependency_type": "chained"
    },
    ...
}
```  
A `dependency_type` with the value `chained`, may be used on an Action, or chain of Actions, that follows immediately after an Action that specifies a `depends_on` target using the properties `role`, `action` and (optionally) `phase`. The Action will be *chained onto* the previous Action, and as such, the Action, or chain of Actions, will be executed *after* any occurrance of that Action. 
