# dry.module.credential

This module handles crendentials for DryDeploy. 

Any DryDeploy `action` may be specified with one or more credential-aliases in it's credentials property. For instance, when an action requires a credential-alias `domain-admin` (`"credential1": "domain-admin"`), that credential is sent to this module for lookup. If no credential in it's store has an alias `domain-admin`, the user is prompted for it. 

Once gathered, the credential aliased `domain-admin` will be stored. The next time an action queries about `domain-admin`, the corresponding credential will be fetched from the module's store, and returned to the action function, so subsequent runs may run without user interaction.

Actions may require one, none, or multiple credentials.  

A credential-alias is specified in any *action*, of a *role*, in the *build* of a system module: 
Example: 
```json
    ...
   {
        "action": "dsc.run",
        "description": "Deploys Active Directory root forest, and first domain controller",
        "phase": 1,
        "order": 2,
        "credentials": 
       {
            "credential1": "ws2019-local-admin",
            "credential2": "domain-admin",
            "credential3": "ws2019-safemode-admin"
        }
    },
    ...
```