/**
 * @id virtio-read
 * @name VirtIO Read
 * @kind problem
 * @problem.severity warning
 * @tags VirtIO
 *       read
 */

import cpp

from FunctionCall call, Function target, string target_name, Function parent_fn
where
	call.getTarget() = target and 
	target.getName() = target_name and (
		target_name = "VirtioPciIoRead" or
		target_name = "VirtioMmioDeviceRead"
	) and
	call.getEnclosingFunction() = parent_fn
select parent_fn, parent_fn.getName()