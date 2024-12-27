ARG ELEMENTAL_BASE

FROM ${ELEMENTAL_BASE} AS os

# Good for validation after the build
CMD ["/bin/bash"]
