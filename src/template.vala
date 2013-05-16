using Gee;

namespace XSRSS
{
	public class Template : Object
	{
		private HashMap<string,string> variables;
		private HashMap<string,LinkedList<HashMap<string,string>>> foreaches;
		private bool is_main_template = false;
		private string subtemplate_file;
		
		public Template(string subtemplate_file,bool is_main = true, HashMap<string,string> variables = new HashMap<string,string>(), HashMap<string,LinkedList<HashMap<string,string>>> foreaches = new HashMap<string,LinkedList<HashMap<string,string>>>())
		{
			is_main_template = is_main;
			this.subtemplate_file = subtemplate_file;
			this.variables = variables;
			this.foreaches = foreaches;
		}

		public void define_variable(string variable,string @value)
		{
			variables[variable] = @value;
		}

		public void define_foreach(string name,LinkedList<HashMap<string,string>> data)
		{
			foreaches[name] = data;
		}

		public string? render()
		{
			string file = is_main_template ? "main" : subtemplate_file;
			if(!FileUtils.test("templates/%s.html".printf(file),FileTest.EXISTS))
			{
				stderr.printf("Template file %s.html does not exist!\n",file);
				return "";
			}
			try
			{
				string rendered_template;
				LinkedList<string> found_variables = new LinkedList<string>();
				if(FileUtils.get_contents("templates/%s.html".printf(file),out rendered_template))
				{
					Regex regex = new Regex("\\$([a-zA-Z:]+)\\$");
					MatchInfo match_info;
					if(regex.match(rendered_template,0,out match_info))
					{
						while(match_info.fetch(1) != null)
						{
							found_variables.add(match_info.fetch(1));
							match_info.next();
						}
					} else
					{
						stdout.printf("No variables in file %s.html\n",file);
					}
					foreach(string variable in found_variables)
					{
						if(variable == "pathtemplate")
						{
							Template subtemplate = new Template(subtemplate_file,false,variables,foreaches);
							rendered_template = rendered_template.replace("$pathtemplate$",subtemplate.render());
						} else if(variable.has_prefix("include:"))
						{
							Template included_file = new Template(variable.substring(8),false,variables);
							rendered_template = rendered_template.replace("$%s$".printf(variable),included_file.render());
						} else if(variable.has_prefix("foreach:"))
						{
							string loop_name = variable.substring(8);
							if(foreaches.has_key(loop_name))
							{
								StringBuilder unwound_loop = new StringBuilder();
								foreach(HashMap<string,string> var_list in foreaches[loop_name])
								{
									Template subfile = new Template(loop_name,false,var_list);
									unwound_loop.append(subfile.render());
								}
								rendered_template = rendered_template.replace("$%s$".printf(variable),unwound_loop.str);
							} else
							{
								stdout.printf("Undefined foreach in file %s: %s\n",file,loop_name);
								rendered_template = rendered_template.replace("$%s$".printf(variable),"");
							}
						} else
						{
							if(variables.has_key(variable))
							{
								rendered_template = rendered_template.replace("$%s$".printf(variable),variables[variable]);
							} else
							{
								stdout.printf("Undefined variable in template %s.html: %s\n",file,variable);
								rendered_template = rendered_template.replace("$%s$".printf(variable),"");
							}
						}
					}
					return rendered_template;
				} else
				{
					stderr.printf("Template %s.html not found!\n",file);
					return "";
				}
			} catch(Error e)
			{
				stderr.printf("Exception while parsing template: %s\n",e.message);
				return "";
			}
		}
	}
}
