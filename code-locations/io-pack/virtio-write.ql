/**
 * @id virtio-write
 * @name VirtIO Write
 * @kind problem
 * @problem.severity warning
 * @tags VirtIO
 *       write
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "VirtioPciIoWrite" or
		target_name = "VirtioMmioDeviceWrite"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()