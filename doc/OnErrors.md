# Errors
How do you find the exception type, so you may catch that specific exception and deal with it specificly?

You have to look at the exception property, use it's GetType method, and extract 
```powershell
c:\> $Error[0].Exception
Cannot find path 'C:\does\not\exist.txt' because it does not exist.

c:\> $Error[0].Exception.GetType()                              
IsPublic IsSerial Name                                     BaseType
-------- -------- ----                                     --------
True     True     ItemNotFoundException                    System.Management.Automation.SessionStateException

c:\> $Error[0].Exception.GetType().Fullname
System.Management.Automation.ItemNotFoundException
```