
# Populate codeql queries for Pio, Mmio, Virtio, CR and MSR functions based on a query template

# path to code-locations directory; the qlpack will be created here
DIR_PATH = './io-pack'
# path to the query template
TEMPLATE = DIR_PATH + '/query.template'
IO_ACTIONS = ['read', 'write']

# keyword identifiers
kw_id = '<q-id>'
kw_name = '<q-name>'
kw_action = '<q-action>'
kw_tag = '<q-tag>'

# create a keyword-replacement dict
def gen_replacement_dict(comp: str, action: str) -> dict:
	# create rest of replacements from component & action
	q_id = comp
	q_name = comp.capitalize()
	q_action = action.capitalize()
	q_tag = q_name

	# replacement dict
	keyword_replacements = {
		kw_id: q_id,
		kw_name: q_name,
		kw_action: q_action,
		kw_tag: q_tag,
	}
	return keyword_replacements

# replace keywords in a string list according to a replacements dict
def strlist_replace(str_list: list, replacements: dict) -> list:
	new_list = []
	for s in str_list:
		for keyword, replacement in replacements.items():
			s = s.replace(keyword, replacement)
		new_list.append(s)
	return new_list

# read a template file, replace all keywords & return the replaced content (string list)
def template_replace(template_name: str, comp: str, action: str) -> list:
	keyword_replacements = gen_replacement_dict(comp, action)

	with open(template_name, 'r') as f:
		lines = f.readlines()

	return strlist_replace(lines, keyword_replacements)

# call template_replace fn & write new content to codeql query file
def populate_ql_files(template_name: str, components: list, actions: list) -> None:
	for comp in components:
		for action in actions:
			out_lines = template_replace(template_name, comp, action)

		qlfile_name = '%s.ql' % comp
		with open(DIR_PATH + '/' + qlfile_name, 'w') as f:
			f.writelines(out_lines)

if __name__ == '__main__':
	comps = ['pio', 'mmio', 'msr', 'cr', 'virtio', 'pci']
	populate_ql_files(TEMPLATE, comps, IO_ACTIONS)