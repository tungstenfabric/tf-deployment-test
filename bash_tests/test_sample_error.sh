#!/bin/bash
# You cat write error info to stderror. IT will be deispay in the test output with stderr label
echo "Test fails" > /proc/self/fd/2
# If script finishes with not null result code test considered as failed
exit 1
