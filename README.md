# 601-Main-Project-Secure-Enclaves
Build MI6 processor with DAWG and other attack vector mitigations

Our idea is to build an MI6 processor with DAWG security, adding mitigations against other known security vulnerabilities of secure enclaves. 

Our product mission is: "For hardware-level security researchers, the Tulong (Earth Dragon in Chinese), is a RISC-V-based out-of-order processor based on MIT CSAIL's MI6 and DAWG with additional mitigations against known secure enclave vulnerabilities, that provides an open-source, flexible, modular platform for testing and assessing the functionality and impact of proposed attack vector mitigations. Unlike most secure enclave research platforms (FIND SPECIFIC EXAMPLES TO CITE), our product incorporates a holistic threat model that allows researchers to more accurately assess the real-world costs of cumulative attack vector mitigations."

Our primary 'customer' (this will be open source) is researchers trying to assess security concerns and their mitigations' performace impact in secure enclaves.

Therefore, our user story is: "I, a researcher, want to have a modular platform on which to test the functionality, interaction, and performance impact of security measures in secure enclaves." (Interaction meaning code reuse or interference between mitigations and/or creation of new attack vectors by the mitigation of one or more known attack vectors).

Our Minimum Valuable Product is an MI6 Processor with DAWG and other vulnerability mitigations, built on one (or more) PFGA board(s) for testing functionality, interaction, and performance. All code created and modified will be open source.

The major components needed for the project are:
- MI6 and DAWG source code (verilog and C++) from github (already open source)
- Source code/hardware designs (as applicable) for mitigating Spectre. Meltdown, Foreshadow, and other secure enclave vulnerabilities (for all relevant side channels)
- FPGA board(s) for implementation

