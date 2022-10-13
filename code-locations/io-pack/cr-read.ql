/**
 * @id cr-read
 * @name CR Read
 * @kind problem
 * @problem.severity warning
 * @tags CR
 *       read
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "AsmReadCr0" or
		target_name = "AsmReadCr2" or
		target_name = "AsmReadCr3" or
		target_name = "AsmReadCr4"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()