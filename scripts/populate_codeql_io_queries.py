

DIR_PATH = '../code-locations/io-pack'
TEMPLATE = DIR_PATH + '/query.template'
IO_ACTIONS = ['read', 'write']

kw_id = '<q-id>'
kw_name = '<q-name>'
kw_action = '<q-action>'
kw_tag = '<q-tag>'
kw_fname_1 = '<q-fname-1>'
kw_fname_2 = '<q-fname-2>'
kw_fname_3 = '<q-fname-3>'
kw_fname_4 = '<q-fname-4>'


def gen_replacement_comp_action(comp, action, f_counters=[8, 16, 32, 64], f_prefix='', f_postfix='', id_prefix=''):
	uc_comp = comp.capitalize()
	uc_action = action.capitalize()
	tag = comp.upper()

	id = '%s%s-%s' % (id_prefix, comp, action)
	name = '%s %s' % (tag, uc_action)
	fname = '%s%s%s%s' % (f_prefix, uc_comp, uc_action, f_postfix)

	keyword_replacements = {
		kw_id: id,
		kw_name: name,
		kw_action: action,
		kw_tag: tag,
		kw_fname_1: fname + str(f_counters[0]),
		kw_fname_2: fname + str(f_counters[1]),
		kw_fname_3: fname + str(f_counters[2]),
		kw_fname_4: fname + str(f_counters[3])
	}
	return keyword_replacements

def gen_replacement_action_comp(comp, action, f_counters=[8, 16, 32, 64], f_prefix='', f_postfix='', id_prefix=''):
	uc_comp = comp.capitalize()
	uc_action = action.capitalize()
	tag = comp.upper()

	id = '%s%s-%s' % (id_prefix, comp, action)
	name = '%s %s' % (tag, uc_action)
	fname = '%s%s%s%s' % (f_prefix, uc_action, uc_comp, f_postfix)

	keyword_replacements = {
		kw_id: id,
		kw_name: name,
		kw_action: action,
		kw_tag: tag,
		kw_fname_1: fname + str(f_counters[0]),
		kw_fname_2: fname + str(f_counters[1]),
		kw_fname_3: fname + str(f_counters[2]),
		kw_fname_4: fname + str(f_counters[3])
	}
	return keyword_replacements

def gen_io_std_replacement(comp, action, id_prefix=''):
	return gen_replacement_comp_action(comp, action, id_prefix='')

def gen_io_buf_replacement(comp, action, id_prefix=''):
	postfix = 'Buffer'
	return gen_replacement_comp_action(comp, action, f_postfix=postfix, id_prefix=id_prefix)

def gen_s3_std_replacement(comp, action, id_prefix=''):
	prefix = 'S3'
	return gen_replacement_comp_action(comp, action, f_prefix=prefix, id_prefix=id_prefix)

def gen_s3_buf_replacement(comp, action, id_prefix=''):
	prefix = 'S3'
	postfix = 'Buffer'
	return gen_replacement_comp_action(comp, action, f_prefix=prefix, f_postfix=postfix, id_prefix=id_prefix)

def gen_td_replacement(comp, action, id_prefix=''):
	prefix = 'Td'
	return gen_replacement_comp_action(comp, action, f_prefix=prefix, id_prefix=id_prefix)

def gen_msr_replacement(comp, action, id_prefix=''):
	prefix = 'Asm'
	return gen_replacement_action_comp(comp, action, f_prefix=prefix, id_prefix=id_prefix)

def gen_cr_replacement(comp, action, id_prefix=''):
	prefix = 'Asm'
	counters = [0, 2, 3, 4]
	return gen_replacement_action_comp(comp, action, f_prefix=prefix, f_counters=counters, id_prefix=id_prefix)



def apply_replacement_on_strlist(str_list, replacements, id_prefix=''):
	new_list = []
	for s in str_list:
		for keyword, replacement in replacements.items():
			s = s.replace(keyword, replacement)
		new_list.append(s)
	return new_list


def apply_replacement_on_template(template_name: str, comp: str, action: str, gen_replacement_dict, id_prefix=''):
	keyword_replacements = gen_replacement_dict(comp, action, id_prefix=id_prefix)

	with open(template_name, 'r') as f:
		lines = f.readlines()

	out_lines = apply_replacement_on_strlist(lines, keyword_replacements, id_prefix=id_prefix)
	return out_lines


def populate_ql_files(template_name: str, components: list[str], actions: list[str], gen_replacement_dict, file_prefix=''):
	for comp in components:
		for action in actions:
			out_lines = apply_replacement_on_template(template_name, comp, action, gen_replacement_dict, id_prefix=file_prefix)

			qlfile_name = '%s%s-%s.ql' % (file_prefix, comp, action)
			with open(DIR_PATH + '/' + qlfile_name, 'w') as f:
				f.writelines(out_lines)

			# print('Content of %s:' % qlfile_name)
			# for l in out_lines:
			# 	print(l, end='')
			# print()


if __name__ == '__main__':

	# PIO
	pio_components = ['pio']
	populate_ql_files(TEMPLATE, pio_components, IO_ACTIONS, gen_io_std_replacement)

	# MMIO
	mmio_components = ['mmio']
	populate_ql_files(TEMPLATE, mmio_components, IO_ACTIONS, gen_td_replacement, file_prefix='td-')
	populate_ql_files(TEMPLATE, mmio_components, IO_ACTIONS, gen_io_std_replacement)
	# populate_ql_files(TEMPLATE, mmio_components, IO_ACTIONS, gen_io_buf_replacement, file_prefix='buf-')
	# populate_ql_files(TEMPLATE, mmio_components, IO_ACTIONS, gen_s3_std_replacement, file_prefix='s3-')
	# populate_ql_files(TEMPLATE, mmio_components, IO_ACTIONS, gen_s3_buf_replacement, file_prefix='s3-buf-')

	# MSR
	msr_components = ['msr']
	populate_ql_files(TEMPLATE, msr_components, IO_ACTIONS, gen_msr_replacement)

	# CR
	msr_components = ['cr']
	populate_ql_files(TEMPLATE, msr_components, IO_ACTIONS, gen_cr_replacement)
