/**
 * @id pci
 * @name Pci
 * @kind problem
 * @problem.severity warning
 * @tags Pci
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name.regexpMatch(".*Pci.*Read.*") or
		target_name.regexpMatch(".*Read.*Pci.*") or
		target_name.regexpMatch(".*Pci.*Write.*") or
		target_name.regexpMatch(".*Write.*Pci.*")
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, target_name