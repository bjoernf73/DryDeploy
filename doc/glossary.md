# The `DryDeploy` Glossary

## Roles

- `role`: Is not an instance, but a *blueprint* of some configurable thing. For instance, the first Domain Controller in a forest has certain configurations attached to it. The `role` is a repository of the configuration files used to describe the build of that role, but the as a *blueprint*, it lacks the variable values that makes it an instance. 

- `resource`: Is an instantiation of a `role`. A `resource` is unique. If you delete it, that `resource` is gone, never to surface again in history. Any new instantiation of a `role`, even with the same name, same property values, is a different `resource`. 

## EnvConfigs
- `EnvConfig`: is a configuration that describes an environment. If you're DevOpsing, you should have at least 3 environments, a dev, a test, in addition to your production. Even in a home lab, you should have at least 3 envs.
- `ModuleConfigs`: is a repository that describes how one or multiple `roles`



## ModuleConfigs

When defining a resource (an instance of a role), instead of specifying types for each action that builds the resource, it should be possible to specify a predefined variant of the resource. The variant definition contains a collection of types for each action that builds the resource.

For instance, you wanna delegate rights down to the instance-level (or computer-level - same thing) on a specific instance of an SQL-server, or group of SQL-servers, because some development team is readily making modifications to those servers in production (a typical scenario). They need administrative privileges to that server, or those servers, but not to any other (for instance, not to the SQL-server that holds every employee's salary). In that case, the Operating System clone action (probably performed by terra.run) will be the same as for any other SQL-server. However, the Active Directory configuration (definately the DryDeploy-native action ad.import) should be invoked as a computer scoped type, and not as a domain scoped type. That may also be the case for the SQL-install itself (perhaps invoked by the action packer.run or dsc.run), since that action contains the scripts to delegate rights to the SQL instance.

As such, variants define a collection of types for actions, excluding default action types.

So, instead of specifying the resource with different Action-types by use of the property options in a module's Build like this: