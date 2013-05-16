using Gee;

namespace XSRSS
{
	public class Template : Object
	{
		private HashMap<string,string> variables;
		private bool is_main_template = false;
		private string subtemplate_file;
		
		public Template(string subtemplate_file,bool is_main = true, HashMap<string,string> variables = new HashMap<string,string>())
		{
			is_main_template = is_main;
			this.subtemplate_file = subtemplate_file;
			this.variables = variables;
		}

		public void define_variable(string variable,string @value)
		{
			variables[variable] = @value;
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
					// Using a regex to get the list of variables is probably
					// the simplest way to do this, but it doesn't allow for
					// implementing foreach loops easily, but hopefully we
					// won't need that
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
							Template subtemplate = new Template(subtemplate_file,false,variables);
							rendered_template = rendered_template.replace("$pathtemplate$",subtemplate.render());
						} else if(variable.has_prefix("include:"))
						{
							Template included_file = new Template(variable.substring(8),false,variables);
							rendered_template = rendered_template.replace("$%s$".printf(variable),included_file.render());
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
