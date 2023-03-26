param = input("Enter your modulation scheme:", "s");
modsize = 0; # Size of bits per symbol
ifft_sample = 2048; # Samples for the IFFT
fc_bw = 15e3; # Carrier bandwidth of 15kHz


# Program will ask for a modulation scheme prompt. Modulation scheme names MUST be entered as below or program will not work.
switch param
    case 'BPSK'
        modsize = 1; # Initialize modulation bit sizes for each case
    case 'QPSK'
        modsize = 2;
    case '16QAM'
        modsize = 4;
    case '64QAM'
        modsize = 6;
end
# Encode message into ASCII using single-row column-space vector
msg_raw = "WirelessCommunicationSystemsandSecurityHarshilJani";
msg_en=dec2bin(double(msg_raw),8)'
msg_en=msg_en(:)';

# Establish parameters and message
qam64 = 6; # bits per symbol for each modulation
qam16 = 4;
qpsk = 2;
bpsk = 1;

# Define subframe
data_rate = 30.72e6; # in MHz
sf_period = 1e-3; #1ms subframe period
slot_period = 0.5e-3 # 0.5 ms slot period
sl_p_sf = sf_period/slot_period; # Slots per subframe
sym_slot = 7 # Symbols per slot
ofdm_mod = 2048 # Modulation symbols per OFDM symbol


max_len = modsize*ofdm_mod*sym_slot*sl_p_sf; # Length of symbols needed to transfer via 64QAM for 1ms (in bytes)
rep = ceil(max_len/length(msg_en)); # How many times the message must repeat for 64QAM
msg_ext = repmat(msg_en,1,rep); #Extend the message for 1ms
msg_sym = [];

#tsample = 1e-3/(length(msg_ext)/modsize) Tsample value used when testing the plots to see if they work
tsample = 1e-3/2047
t = 0:tsample:1e-3;

# OFDM Symbol Conversion
for b = 1:(length(msg_ext)/modsize)
  # Take the appropriate symbol's width of characters at a time depending on modulation scheme
  sym_raw = substr(msg_ext, modsize*b-(modsize-1), modsize);
  switch param
    case 'BPSK'
      # In BPSK, all you have to check for is if the bit is 1, you negate both components
      ivar = 1/sqrt(2); # Default value is 1/sqrt(2)
      qvar = 1/sqrt(2);
      if sym_raw == "1"
        ivar = ivar*-1;
        qvar = qvar*-1;
      endif
      msg_sym = [msg_sym, ivar+j*qvar];
    case 'QPSK'
      # In QPSK, there's two bits corresponding to each component, 1 negates the corresponding component
      vars = [1/sqrt(2), 1/sqrt(2)];
      for a = 1:2
        if sym_raw(a) == '1'
          vars(a) = vars(a)*-1; # The element to be negated depends on the position of the 1 bit
        endif
      endfor
      msg_sym = [msg_sym, vars(1) + vars(2)*j];
    case '16QAM'
      # In 16QAM, the first two bits are sign bits, the second two are value bits
      # Each bit in each pair corresponds to a component (I or Q)
      vars = [1/sqrt(10), 1/sqrt(10)];
      # Process last two bits
      for a = 3:4
        if sym_raw(a) == '1'
          vars(a-2) = 3/sqrt(10);
        endif
      endfor
      # Process first two bits
      for a = 1:2
        if sym_raw(a) == '1'
          vars(a) = vars(a)*-1;
        endif
      endfor
      msg_sym = [msg_sym, vars(1) + vars(2)*j];
   case '64QAM'
      # In 64QAM, last two pairs of bits can sum up in their toggles to create four combinational values, the first pair are still sign bits
      vars = [3/sqrt(42), 3/sqrt(42)]; # Initialize I and Q to 3/sqrt(42)
      # Process last two bits
      for a = 5:6
        if sym_raw(a) == '1'
          vars(a-4) = 1/sqrt(42);
        endif
      endfor
      # Process middle bits
      for a = 3:4
        if sym_raw(a) == '1'
          vars(a-2) = 8/sqrt(42) - vars(a-2);
        endif
      endfor
      # Process first bits
      for a = 1:2
        if sym_raw(a) == '1'
          vars(a) = vars(a)*-1;
        endif
      endfor
      msg_sym = [msg_sym, vars(1) + vars(2)*j];
   end
endfor

out_buf = [];

# For all slots, note that traditional way is to do a loop of 2048 to fill a buffer then clock, but that'd be inefficient so I'm doing a matrix to emulate clock
for s = 1:(sl_p_sf*sym_slot)
  # Serial to parallel conversion
  buf = msg_sym(ofdm_mod*(s-1)+1:ofdm_mod*s); # Temporary buffer for sending out 2048 mod symbols

  # Perform IFFT to convert them into an OFDM symbol
  ofdm_sym = ifft(buf, 2048);

  # Add a cyclic prefix depending on if first symbol or not
  init_cp = 5.2e-6;
  cp = 4.7e-6;

  ofdm_sym(1) = ofdm_sym(1) + init_cp; # Add CP of 5.2us to first element
  ofdm_sym(2:length(ofdm_sym)) = ofdm_sym(2:length(ofdm_sym)) + cp; # Add CP of 4.7us to rest

  # Collect symbol into output buffer
  out_buf = [out_buf; ofdm_sym];
endfor

# Transpose output buffer so it actually maps to the subcarriers
out_buf = transpose(out_buf); # Transpose into columns

# Plot the first two OFDM symbols, as instructed
sym_plot = out_buf(:,1:2);
plot_title = ['OFDM Symbols 1-2 ', param];
plot(t, sig_out)
title(plot_title)
xlabel('Time(s)')






# Code below here is junk, left in here just incase since it has a working way to convert the complex numbers into sinusoids

#   # Iterate through all symbols filling 2048 slots, reset to 2048 when you've filled buffer
#  amp = abs(msg_sym(s)); # Get the amplitude of the given symbol
#  theta = angle(msg_sym(s)); # Get the phase of the given symbol
#  fc = fc_bw*(2048-ifft_sample); # Carrier frequency will be 15kHz multiplied by the number signal you're on out of the 2048 slots
#  # Might need to add cos and sin signals to account for the imaginary number
#  sig = amp*cos(2*pi*fc*t + theta) + amp*sin(2*pi*fc*t + theta) + amp*cos(2*pi*(-fc)*t + theta); + amp*sin(2*pi*(-fc)*t + theta);
#  sig_buf = [sig_buf, sig];
