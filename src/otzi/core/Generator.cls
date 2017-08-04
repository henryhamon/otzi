Class otzi.core.Generator
{

/// Validate the ClassMethod Project arguments
ClassMethod Validate(args...) As %Status
{
	Set tSC = $$$OK
	Try {
		Set:$Get(args(1))="" tSC = $$$ERROR(6404, "Namespace")
		Throw:$$$ISERR(tSC)
		Set:$Get(args(2))="" tSC = $$$ERROR(6404, "Template")
		Throw:$$$ISERR(tSC)
		Set:$ClassName(args(2))'="otzi.core.vo.Template" tSC = $$$ERROR(6405,"Template","otzi.core.vo.Template")
		Throw:$$$ISERR(tSC)
	} Catch tException {
		Set:$$$ISOK(tSC) tSC = tException.AsStatus()
	}
	Quit tSC
}

/// Load all classes from a template project and create
ClassMethod Project(args...) As %Status
{
	Set tSC = ..Validate(args...)
	Quit:$$$ISERR(tSC) tSC

	
	Set pNamespace = args(1),
	    pTemplate = args(2),
	    pPackage = $Get(args(3)),
	    pProject = $Get(args(4)),
	    pIgnore = $Get(args(5))
	Set:pIgnore="" pIgnore = 1
	
	Try {
		For k=1:1:pTemplate.Classes.Count() {
			
			$$$THROWONERROR(tSC, ..Class(pNamespace, pTemplate.Classes.GetAt(k), pPackage, pProject, pIgnore))
		}
	} Catch tException {
		Set:$$$ISOK(tSC) tSC = tException.AsStatus()
	}
	Quit tSC
}

ClassMethod Class(args...) As %Status [ Private ]
{
	Set ns=$Namespace, tSC = $$$OK
	/*
	 pNamespace As %String, 
	 pTemplate As otzi.core.vo.Template.Class, 
	 pPackage As %String = "", 
	 pProject As %String = "", 
	 pIgnore As %Boolean = 1
	*/
	Set pNamespace = args(1),
	    pTemplate = $Get(args(2)),
	    pPackage = $Get(args(3)),
	    pProject = $Get(args(4)),
	    pIgnore = $Get(args(5))
	Set:pIgnore="" pIgnore = 1
	
	#Dim pTemplate As otzi.core.vo.Template.Class
	
	Try {
		Set:pTemplate="" tSC = $$$ERROR(6404, "Template Class")
		Throw:$$$ISERR(tSC)
		
		Set className = pTemplate.Name, newClass = ""
		
		If $Extract(className,1,1)="." {
			S className = ""
			Set:pPackage'="" $List(className,*+1) = pPackage
			Set:pProject'="" $List(className,*+1) = pProject
			
			Set className = $ListToString(className,".")_pTemplate.Name
		} 
		
		Set className = ..Replace(pPackage, pProject, className)
		Set superClass = ..Replace(pPackage, pProject, pTemplate.Super)

		ZNSpace pNamespace
			Set newClass = ##class(%Dictionary.ClassDefinition).%OpenId(className)
		ZNSpace ns
		
		Set:((newClass'="")&&(pIgnore=0)) tSC = $$$ERROR(5805)
		If newClass="" {
			W !,className,!

			ZNSpace pNamespace
			Set newClass = ##class(%Dictionary.ClassDefinition).%New()
			Set newClass.Name = className
			Set newClass.Super = superClass
			Set newClass.ProcedureBlock = 1
			Do newClass.%Save()
			
			If ((pTemplate.Name["utl.Instalador")||(pTemplate.Name["Install")) {
				// If this was an install class (used to create web aplication)
				// then add a projection
				Set projection = ##class(%Dictionary.ProjectionDefinition).%New()
				Set projection.Name = "Reference"
				Set projection.Type = "Instalador"
				Do newClass.Projections.Insert(projection)
				Do newClass.%Save()
			}
			
			// Properties
			For p=1:1:pTemplate.Properties.Count() {
				Set property = ##class(%Dictionary.PropertyDefinition).%New()
				
				ZNSpace ns
					Set property.Name = ..Replace(pPackage, pProject, pTemplate.Properties.GetAt(p).Name)
					Set property.Type = ..Replace(pPackage, pProject, pTemplate.Properties.GetAt(p).Value)
				ZNSpace pNamespace
				
				Set:pTemplate.Properties.GetAt(p).List'="" property.Collection = "list"
				If (pTemplate.Properties.GetAt(p).Parameters.Count() > 0) {
					For param=1:1:pTemplate.Properties.GetAt(p).Parameters.Count() {
						#Dim parameter As otzi.core.vo.Parameter
						Set parameter = pTemplate.Properties.GetAt(p).Parameters.GetAt(param)
						
						Set paramValue ="",paramName =""
						ZNSpace ns
							Set paramValue = ..Replace(pPackage, pProject, parameter.Value)
							Set paramName = ..Replace(pPackage, pProject, parameter.Name)
						ZNSpace pNamespace
						Do property.Parameters.SetAt(paramValue, paramName)
					}
				}

				$$$THROWONERROR(tSC, newClass.Properties.Insert(property) )
				
				// Create simple Index
				If pTemplate.Properties.GetAt(p).Index'="" {
					Set indice = ##class(%Dictionary.IndexDefinition).%New()
					Set indice.Name = "Idx"_property.Name
					Set indice.Properties = property.Name
					$$$THROWONERROR(tSC, newClass.Indices.Insert(indice) )
				}
			}
			$$$THROWONERROR(tSC, newClass.%Save() )
			
			// Methods
			For m=1:1:pTemplate.Methods.Count() {
				Set method = ##class(%Dictionary.MethodDefinition).%New()
				Set method.ClassMethod = 0, parameter = ""
				
				Set:pTemplate.Methods.GetAt(m).Type="Class" method.ClassMethod = 1
				Set:pTemplate.Methods.GetAt(m).Type="Client" method.ClientMethod = 1
				Set:pTemplate.Methods.GetAt(m).Parameters'="" parameter = pTemplate.Methods.GetAt(m).Parameters
				
				ZNSpace ns
					Set method.Name = ..Replace(pPackage, pProject, pTemplate.Methods.GetAt(m).Name)
					Set:pTemplate.Methods.GetAt(m).Value'="" method.ReturnType = ..Replace(pPackage, pProject, pTemplate.Methods.GetAt(m).Value)
					Do method.Implementation.Write( ..Replace(pPackage, pProject, pTemplate.Methods.GetAt(m).Implementation.Read()) )
					Set:parameter'="" method.FormalSpec = ..Replace(pPackage, pProject, parameter)
				ZNSpace pNamespace

				$$$THROWONERROR(tSC, newClass.Methods.Insert(method) )
			}
			$$$THROWONERROR(tSC, newClass.%Save() )
			
			
			// Parameters
			For p=1:1:pTemplate.Parameters.Count() {
				Set parameter = ##class(%Dictionary.ParameterDefinition).%New()
				
				ZNSpace ns
					Set parameter.Name = ..Replace(pPackage, pProject, pTemplate.Parameters.GetAt(p).Name)
					Set:pTemplate.Parameters.GetAt(p).Value'="" parameter.Default = ..Replace(pPackage, pProject, pTemplate.Parameters.GetAt(p).Value)
				ZNSpace pNamespace
				
				Set parameter.Expression = ""
				
				$$$THROWONERROR(tSC, newClass.Parameters.Insert(parameter) )
			}
			$$$THROWONERROR(tSC, newClass.%Save() )
			
			
			// Routes
			Set routes = ""
			If pTemplate.Routes.Count() > 0 {
				For p=1:1:pTemplate.Routes.Count() {
					ZNSpace ns
						Set routes = routes _ "<Route Url=""/"_ ..Replace(pPackage, pProject, pTemplate.Routes.GetAt(p).Name )
						Set routes = routes _ """ Method="""_..Replace(pPackage, pProject, pTemplate.Routes.GetAt(p).Value) _""" Call="""_..Replace(pPackage, pProject, pTemplate.Routes.GetAt(p).Call) _"""/>"
					ZNSpace pNamespace
				}
			
				Set routes = "<Routes>" _ routes _ "</Routes>"
				Set route = ##class(%Dictionary.XDataDefinition).%New()
				Set route.Name = "UrlMap"
				Do route.Data.Write(routes)
				$$$THROWONERROR(tSC, newClass.XDatas.Insert(route))
			}
			$$$THROWONERROR(tSC, newClass.%Save() )
			
			If pTemplate.Bpl.Read() '="" {
				Do pTemplate.Bpl.Rewind()
				Set xdata = ##class(%Dictionary.XDataDefinition).%New()
				Set xdata.Name = "BPL"
				Set xdata.Description = "BPL Definition"
				
				ZNSpace ns
					Do xdata.Data.Write(..Replace(pPackage, pProject, pTemplate.Bpl.Read()))		
				ZNSpace pNamespace
				
				$$$THROWONERROR(tSC, newClass.XDatas.Insert(xdata))
			}
			$$$THROWONERROR(tSC, newClass.%Save() )
			
			If ((pTemplate.Page.Style.Read()'="")||(pTemplate.Page.Content.Read()'="")) {
				
				Set content = ##class(%GlobalCharacterStream).%New(), 
					page = $ListBuild("Style","Contents")
					
				For p=1:1:$ListLength(page) {
					Do:p=1 content.CopyFrom(pTemplate.Page.Style)
					Do:p=2 content.CopyFrom(pTemplate.Page.Content)
					Do content.Rewind()
					If content.Read()'="" {
						Do content.Rewind()
						Set xdata = ##class(%Dictionary.XDataDefinition).%New()
						Set xdata.Name = $List(page, p)
						;Set xdata.Description = ""
						
						ZNSpace ns
							Do xdata.Data.Write(..Replace(pPackage, pProject, content.Read()))		
						ZNSpace pNamespace
					
						$$$THROWONERROR(tSC, newClass.XDatas.Insert(xdata))
					}
				}
				$$$THROWONERROR(tSC, newClass.%Save() )
			}
			
			Do:((newClass.Name'["Instalador")||(newClass.Name'["Install")) $system.OBJ.Compile(newClass.Name)
		}

	} Catch tException {
		Set:$$$ISOK(tSC) tSC=tException.AsStatus()
	}
	
	ZNSpace ns
	
	Quit tSC
}

/// The <b>Replace</b> method add the package and project names to classname
ClassMethod Replace(pPackage As %String = "", pProject As %String = "", pParam As %String) As %String [ Private ]
{
	Set output = pParam
	Set lowText = $ZConvert(pProject,"l")
	Set camelText = $Extract($ZConvert(lowText,"U"),1,1) _ $Extract($ZConvert(lowText,"l"),2,*)
	
	Set pkgPrj = ""
	Set:pPackage'="" $List(pkgPrj,*+1) = pPackage
	Set:pProject'="" $List(pkgPrj,*+1) = pProject
	Set pkgPrj = $ListToString(pkgPrj,".")
	
	Set output = $Replace(output,"#{package.project}",pkgPrj)
	Set output = $Replace(output,"#{project}",pProject)
	Set output = $Replace(output,"#{Camelcase.project}", camelText)
	Set output = $Replace(output,"#{camel.project}", camelText)
	Set output = $Replace(output,"#{package}", pPackage)
	Set output = $Replace(output,"#{database.packagename}", $Replace(pPackage,".","_"))
	Quit output
}

}
