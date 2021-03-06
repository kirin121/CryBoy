enum FlagOp
  ZERO
  ONE
  DEFAULT
  UNCHANGED
end

class CPU
  macro register(upper, lower)
    property {{upper.id}} : UInt8 = 0_u8
    property {{lower.id}} : UInt8 = 0_u8

    def {{upper.id}}{{lower.id}} : UInt16
      (@{{upper}}.to_u16 << 8 | @{{lower}}.to_u16).not_nil!
    end

    def {{upper.id}}{{lower.id}}=(value : UInt16)
      @{{upper.id}} = (value >> 8).to_u8
      @{{lower.id}} = (value & 0xFF).to_u8
    end

    def {{upper.id}}{{lower.id}}=(value : UInt8)
      @{{upper.id}} = 0_u8
      @{{lower.id}} = value
    end
  end

  macro flag(name, mask)
    def f_{{name.id}}=(on : Int | Bool)
      if on == false || on == 0
        @f &= ~{{mask}}
      else
        @f |= {{mask.id}}
      end
    end

    def f_{{name.id}} : Bool
      @f & {{mask.id}} == {{mask.id}}
    end

    def f_n{{name.id}} : Bool
      !f_{{name.id}}
    end
  end

  register a, f
  register b, c
  register d, e
  register h, l

  flag z, 0b10000000
  flag n, 0b01000000
  flag h, 0b00100000
  flag c, 0b00010000

  @ime = true

  property sp
  property pc
  property ime
  property memory

  def initialize(@memory : Memory, boot = false)
    @pc = 0x0000_u16
    @sp = 0xFFFE_u16
    skip_boot if !boot
  end

  def skip_boot
    @pc = 0x0100_u16
    self.af = 0x01B0_u16
    self.bc = 0x0013_u16
    self.de = 0x00D8_u16
    self.hl = 0x014D_u16
    @sp = 0xFFFE_u16
    # set IO reigster state
    @memory[0xFF10] = 0x80_u8
    @memory[0xFF11] = 0xBF_u8
    @memory[0xFF12] = 0xF3_u8
    @memory[0xFF14] = 0xBF_u8
    @memory[0xFF16] = 0x3F_u8
    @memory[0xFF19] = 0xBF_u8
    @memory[0xFF1A] = 0x7F_u8
    @memory[0xFF1B] = 0xFF_u8
    @memory[0xFF1C] = 0x9F_u8
    @memory[0xFF1E] = 0xBF_u8
    @memory[0xFF20] = 0xFF_u8
    @memory[0xFF23] = 0xBF_u8
    @memory[0xFF24] = 0x77_u8
    @memory[0xFF25] = 0xF3_u8
    @memory[0xFF26] = 0xF1_u8
    @memory[0xFF40] = 0x91_u8
    @memory[0xFF41] = 0x05_u8
    @memory[0xFF47] = 0xFC_u8
    @memory[0xFF48] = 0xFF_u8
    @memory[0xFF49] = 0xFF_u8
    # unmap the boot rom
    @memory[0xFF50] = 0x01_u8
  end

  def pop : UInt16
    @memory.read_word (@sp += 2) - 2
  end

  def push(value : UInt16) : Nil
    @memory[@sp -= 2] = value
  end

  def set_flags(res : UInt8, op1 : UInt8, op2 : UInt8, z : FlagOp, n : FlagOp, h : FlagOp, c : FlagOp, add_sub = false)
    # puts "set_flags >> res:#{res}, op1:#{op1}, op2:#{op2}, z:#{z}, n:#{n}, h:#{h}, c:#{c}, add_sub:#{add_sub}"

    case z
    when FlagOp::ZERO    then self.f_z = 0
    when FlagOp::ONE     then self.f_z = 1
    when FlagOp::DEFAULT then self.f_z = res == 0
    when FlagOp::UNCHANGED
    end

    case n
    when FlagOp::ZERO    then self.f_n = 0
    when FlagOp::ONE     then self.f_n = 1
    when FlagOp::DEFAULT then self.f_n = add_sub
    when FlagOp::UNCHANGED
    end

    case h
    when FlagOp::ZERO    then self.f_h = 0
    when FlagOp::ONE     then self.f_h = 1
    when FlagOp::DEFAULT then self.f_h = (op1 ^ op2 ^ res) & 0x10 == 0x10
    when FlagOp::UNCHANGED
    end

    case c
    when FlagOp::ZERO    then self.f_c = 0
    when FlagOp::ONE     then self.f_c = 1
    when FlagOp::DEFAULT then self.f_c = res < op1
    when FlagOp::UNCHANGED
    end
  end

  def add(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 &+ op2
    set_flags res, op1, op2, z, n, h, c, add_sub = true
    res
  end

  def adc(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 &+ op2 &+ (f_c ? 1 : 0)
    set_flags res, op1, op2, z, n, h, c, add_sub = true
    res
  end

  def sub(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 &- op2
    set_flags res, op1, op2, z, n, h, c, add_sub = true
    res
  end

  def sbc(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 &- op2 &- (f_c ? 1 : 0)
    set_flags res, op1, op2, z, n, h, c, add_sub = true
    res
  end

  def and(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 & op2
    set_flags res, op1, op2, z, n, h, c
    res
  end

  def or(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 | op2
    set_flags res, op1, op2, z, n, h, c
    res
  end

  def xor(op1 : UInt8, op2 : UInt8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt8
    res = op1 ^ op2
    set_flags res, op1, op2, z, n, h, c
    res
  end

  def add(op1 : UInt16, op2 : Int8, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt16
    # todo this case is very specific, should be moved elsewhere
    res = op1 &+ op2
    @f = 0b00000000
    @f += (((@sp & 0xF) + (op2.to_u8! & 0xF)) > 0xF) ? 1 : 0 << 5
    @f += (((@sp & 0xFF) + (op2.to_u8! & 0xF)) > 0xF) ? 1 : 0 << 4
    res
  end

  def add(operand_1 : UInt16, operand_2 : UInt16, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED) : UInt16
    res = operand_1 &+ operand_2

    if z == FlagOp::ZERO
      self.f_z = false
    elsif z == FlagOp::ONE || (z == FlagOp::DEFAULT && res == 0)
      self.f_z = true
    end

    if n == FlagOp::ZERO
      self.f_n = false
    elsif n == FlagOp::ONE # || todo
      self.f_n = true
    end

    if h == FlagOp::ZERO
      self.f_h = false
    elsif h == FlagOp::ONE # || todo
      self.f_h = true
    end

    if c == FlagOp::ZERO
      self.f_c = false
    elsif c == FlagOp::ONE || (c == FlagOp::DEFAULT && res < operand_1)
      self.f_c = true
    end

    res
  end

  def bit(op : UInt8, bit : Int) : Nil
    f_z = (op >> bit) & 0x1
    f_n = false
    f_h = true
  end

  def handle_interrupts
    # bit 0: v-blank
    if @memory.vblank && @memory.vblank_enabled
      @memory.vblank = false
      @sp -= 2
      @memory[@sp] = @pc
      @pc = 0x0040_u16
    end
    # bit 1: lcd stat
    if @memory.lcd_stat && @memory.lcd_stat_enabled
      @memory.lcd_stat = false
      @sp -= 2
      @memory[@sp] = @pc
      @pc = 0x0048_u16
    end
    # bit 2: timer
    if @memory.timer && @memory.timer_enabled
      @memory.timer = false
      @sp -= 2
      @memory[@sp] = @pc
      @pc = 0x0050_u16
    end
    # bit 3: serial
    if @memory.serial && @memory.serial_enabled
      @memory.serial = false
      @sp -= 2
      @memory[@sp] = @pc
      @pc = 0x0058_u16
    end
    # bit 4: joypad
    if @memory.joypad && @memory.joypad_enabled
      @memory.joypad = false
      @sp -= 2
      @memory[@sp] = @pc
      @pc = 0x0060_u16
    end
    # clear Interrupt Master Enable
    @ime = false
  end

  # Runs for the specified number of machine cycles. If no argument provided,
  # runs only one instruction. Handles interrupts _after_ the instruction is
  # executed.
  def tick(cycles = 1)
    while cycles > 0
      opcode = read_opcode
      cycles -= process_opcode opcode
      # interrupts
      if opcode == 0x76
        puts "HALT, who goes there (todo)"
      end
      handle_interrupts if @ime
    end
  end

  def read_opcode : UInt8
    @memory[@pc]
  end

  # process the given opcode
  # returns the number of machine cycles taken (where gb runs at 4.19MHz)
  def process_opcode(opcode : UInt8, cb = false) : Int32
    # all cb-prefixed opcodes have a length of 1 + the prefix
    length = cb ? 1 : OPCODE_LENGTHS[opcode]
    d8 : UInt8 = 0_u8
    r8 : Int8 = 0_u8
    d16 : UInt16 = 0_u16
    if length == 2
      d8 = @memory[@pc + 1]
      r8 = d8.to_i8!
    elsif length == 3
      d16_1 = @memory[@pc + 1]
      d16_2 = @memory[@pc + 2]
      d16 = @memory.read_word @pc + 1
    end
    @pc += length

    # Everything below is automatically generated. Once the codegen code is
    # finished and cleaned up, I'll add it to the repo as well.
    if !cb
      case opcode
      when 0x00
        return 4
      when 0x01
        self.bc = d16
        return 12
      when 0x02
        @memory[self.bc] = @a
        return 8
      when 0x03
        @a = add @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x04
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x05
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x06
        @b = d8
        return 8
      when 0x07
        raise "FAILED TO MATCH 0x07"
      when 0x08
        @memory[d16] = @sp
        return 20
      when 0x09
        self.hl = add self.hl, self.bc, z = FlagOp::UNCHANGED, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x0A
        @a = @memory[self.bc]
        return 8
      when 0x0B
        @a = sub @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x0C
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x0D
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x0E
        @c = d8
        return 8
      when 0x0F
        raise "FAILED TO MATCH 0x0F"
      when 0x10
        raise "FAILED TO MATCH 0x10"
      when 0x11
        self.de = d16
        return 12
      when 0x12
        @memory[self.de] = @a
        return 8
      when 0x13
        @a = add @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x14
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x15
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x16
        @d = d8
        return 8
      when 0x17
        raise "FAILED TO MATCH 0x17"
      when 0x18
        @pc &+= r8
        return 12
      when 0x19
        self.hl = add self.hl, self.de, z = FlagOp::UNCHANGED, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x1A
        @a = @memory[self.de]
        return 8
      when 0x1B
        @a = sub @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x1C
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x1D
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x1E
        @e = d8
        return 8
      when 0x1F
        raise "FAILED TO MATCH 0x1F"
      when 0x20
        if f_nz
          @pc &+= r8
          return 12
        end
        return 8
      when 0x21
        self.hl = d16
        return 12
      when 0x22
        @memory[self.hl] = @a
        return 8
      when 0x23
        @a = add @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x24
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x25
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x26
        @h = d8
        return 8
      when 0x27
        raise "FAILED TO MATCH 0x27"
      when 0x28
        if f_z
          @pc &+= r8
          return 12
        end
        return 8
      when 0x29
        self.hl = add self.hl, self.hl, z = FlagOp::UNCHANGED, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x2A
        @a = @memory[self.hl]
        return 8
      when 0x2B
        @a = sub @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x2C
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x2D
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x2E
        @l = d8
        return 8
      when 0x2F
        raise "FAILED TO MATCH 0x2F"
      when 0x30
        if f_nc
          @pc &+= r8
          return 12
        end
        return 8
      when 0x31
        @sp = d16
        return 12
      when 0x32
        @memory[self.hl] = @a
        return 8
      when 0x33
        @a = add @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x34
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 12
      when 0x35
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 12
      when 0x36
        @memory[self.hl] = d8
        return 12
      when 0x37
        raise "FAILED TO MATCH 0x37"
      when 0x38
        if f_c
          @pc &+= r8
          return 12
        end
        return 8
      when 0x39
        self.hl = add self.hl, @sp, z = FlagOp::UNCHANGED, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x3A
        @a = @memory[self.hl]
        return 8
      when 0x3B
        @a = sub @a, 1, z = FlagOp::UNCHANGED, n = FlagOp::UNCHANGED, h = FlagOp::UNCHANGED, c = FlagOp::UNCHANGED
        return 8
      when 0x3C
        @a = add @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x3D
        @a = sub @a, 1, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::UNCHANGED
        return 4
      when 0x3E
        @a = d8
        return 8
      when 0x3F
        raise "FAILED TO MATCH 0x3F"
      when 0x40
        # @b = @b
        return 4
      when 0x41
        @b = @c
        return 4
      when 0x42
        @b = @d
        return 4
      when 0x43
        @b = @e
        return 4
      when 0x44
        @b = @h
        return 4
      when 0x45
        @b = @l
        return 4
      when 0x46
        @b = @memory[self.hl]
        return 8
      when 0x47
        @b = @a
        return 4
      when 0x48
        @c = @b
        return 4
      when 0x49
        # @c = @c
        return 4
      when 0x4A
        @c = @d
        return 4
      when 0x4B
        @c = @e
        return 4
      when 0x4C
        @c = @h
        return 4
      when 0x4D
        @c = @l
        return 4
      when 0x4E
        @c = @memory[self.hl]
        return 8
      when 0x4F
        @c = @a
        return 4
      when 0x50
        @d = @b
        return 4
      when 0x51
        @d = @c
        return 4
      when 0x52
        # @d = @d
        return 4
      when 0x53
        @d = @e
        return 4
      when 0x54
        @d = @h
        return 4
      when 0x55
        @d = @l
        return 4
      when 0x56
        @d = @memory[self.hl]
        return 8
      when 0x57
        @d = @a
        return 4
      when 0x58
        @e = @b
        return 4
      when 0x59
        @e = @c
        return 4
      when 0x5A
        @e = @d
        return 4
      when 0x5B
        # @e = @e
        return 4
      when 0x5C
        @e = @h
        return 4
      when 0x5D
        @e = @l
        return 4
      when 0x5E
        @e = @memory[self.hl]
        return 8
      when 0x5F
        @e = @a
        return 4
      when 0x60
        @h = @b
        return 4
      when 0x61
        @h = @c
        return 4
      when 0x62
        @h = @d
        return 4
      when 0x63
        @h = @e
        return 4
      when 0x64
        # @h = @h
        return 4
      when 0x65
        @h = @l
        return 4
      when 0x66
        @h = @memory[self.hl]
        return 8
      when 0x67
        @h = @a
        return 4
      when 0x68
        @l = @b
        return 4
      when 0x69
        @l = @c
        return 4
      when 0x6A
        @l = @d
        return 4
      when 0x6B
        @l = @e
        return 4
      when 0x6C
        @l = @h
        return 4
      when 0x6D
        # @l = @l
        return 4
      when 0x6E
        @l = @memory[self.hl]
        return 8
      when 0x6F
        @l = @a
        return 4
      when 0x70
        @memory[self.hl] = @b
        return 8
      when 0x71
        @memory[self.hl] = @c
        return 8
      when 0x72
        @memory[self.hl] = @d
        return 8
      when 0x73
        @memory[self.hl] = @e
        return 8
      when 0x74
        @memory[self.hl] = @h
        return 8
      when 0x75
        @memory[self.hl] = @l
        return 8
      when 0x76
        raise "FAILED TO MATCH 0x76"
      when 0x77
        @memory[self.hl] = @a
        return 8
      when 0x78
        @a = @b
        return 4
      when 0x79
        @a = @c
        return 4
      when 0x7A
        @a = @d
        return 4
      when 0x7B
        @a = @e
        return 4
      when 0x7C
        @a = @h
        return 4
      when 0x7D
        @a = @l
        return 4
      when 0x7E
        @a = @memory[self.hl]
        return 8
      when 0x7F
        # @a = @a
        return 4
      when 0x80
        @a = add @a, @b, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x81
        @a = add @a, @c, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x82
        @a = add @a, @d, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x83
        @a = add @a, @e, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x84
        @a = add @a, @h, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x85
        @a = add @a, @l, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x86
        @a = add @a, @memory[self.hl], z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x87
        @a = add @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x88
        @a = adc @a, @b, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x89
        @a = adc @a, @c, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x8A
        @a = adc @a, @d, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x8B
        @a = adc @a, @e, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x8C
        @a = adc @a, @h, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x8D
        @a = adc @a, @l, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x8E
        @a = adc @a, @memory[self.hl], z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x8F
        @a = adc @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x90
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x91
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x92
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x93
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x94
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x95
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x96
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x97
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x98
        @a = sbc @a, @b, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x99
        @a = sbc @a, @c, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x9A
        @a = sbc @a, @d, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x9B
        @a = sbc @a, @e, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x9C
        @a = sbc @a, @h, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x9D
        @a = sbc @a, @l, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0x9E
        @a = sbc @a, @memory[self.hl], z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0x9F
        @a = sbc @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xA0
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA1
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA2
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA3
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA4
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA5
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA6
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 8
      when 0xA7
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 4
      when 0xA8
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xA9
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xAA
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xAB
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xAC
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xAD
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xAE
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 8
      when 0xAF
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB0
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB1
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB2
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB3
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB4
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB5
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB6
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 8
      when 0xB7
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 4
      when 0xB8
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xB9
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xBA
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xBB
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xBC
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xBD
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xBE
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xBF
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 4
      when 0xC0
        if f_nz
          @pc = @memory.read_word @sp; @sp += 2
          return 20
        end
        return 8
      when 0xC1
        self.bc = pop
        return 12
        return 12
      when 0xC2
        if f_nz
          @pc = d16.to_u16
          return 16
        end
        return 12
      when 0xC3
        @pc = d16.to_u16
        return 16
      when 0xC4
        if f_nz
          @sp -= 2
          @memory[@sp] = @pc
          @pc = d16
          return 24
        end
        return 12
      when 0xC5
        push self.bc
        return 16
        return 16
      when 0xC6
        @a = add @a, d8, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xC7
        raise "FAILED TO MATCH 0xC7"
      when 0xC8
        if f_z
          @pc = @memory.read_word @sp; @sp += 2
          return 20
        end
        return 8
      when 0xC9
        @pc = @memory.read_word @sp; @sp += 2
        return 16
        return 16
      when 0xCA
        if f_z
          @pc = d16.to_u16
          return 16
        end
        return 12
      when 0xCB
        next_op = read_opcode
        return 4 + process_opcode next_op, cb = true
        return 4
      when 0xCC
        if f_z
          @sp -= 2
          @memory[@sp] = @pc
          @pc = d16
          return 24
        end
        return 12
      when 0xCD
        @sp -= 2
        @memory[@sp] = @pc
        @pc = d16
        return 24
        return 24
      when 0xCE
        @a = adc @a, d8, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xCF
        raise "FAILED TO MATCH 0xCF"
      when 0xD0
        if f_nc
          @pc = @memory.read_word @sp; @sp += 2
          return 20
        end
        return 8
      when 0xD1
        self.de = pop
        return 12
        return 12
      when 0xD2
        if f_nc
          @pc = d16.to_u16
          return 16
        end
        return 12
        # 0xD3 has no functionality
      when 0xD4
        if f_nc
          @sp -= 2
          @memory[@sp] = @pc
          @pc = d16
          return 24
        end
        return 12
      when 0xD5
        push self.de
        return 16
        return 16
      when 0xD6
        @a = sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xD7
        raise "FAILED TO MATCH 0xD7"
      when 0xD8
        if f_c
          @pc = @memory.read_word @sp; @sp += 2
          return 20
        end
        return 8
      when 0xD9
        @ime = true
        @pc = @memory.read_word @sp; @sp += 2
        return 16
        return 16
      when 0xDA
        if f_c
          @pc = d16.to_u16
          return 16
        end
        return 12
        # 0xDB has no functionality
      when 0xDC
        if f_c
          @sp -= 2
          @memory[@sp] = @pc
          @pc = d16
          return 24
        end
        return 12
        # 0xDD has no functionality
      when 0xDE
        @a = sbc @a, d8, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xDF
        raise "FAILED TO MATCH 0xDF"
      when 0xE0
        @memory[0xFF00 + d8] = @a
        return 12
      when 0xE1
        self.hl = pop
        return 12
        return 12
      when 0xE2
        @memory[@c] = @a
        return 8
        # 0xE3 has no functionality
        # 0xE4 has no functionality
      when 0xE5
        push self.hl
        return 16
        return 16
      when 0xE6
        @a = and @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ONE, c = FlagOp::ZERO
        return 8
      when 0xE7
        raise "FAILED TO MATCH 0xE7"
      when 0xE8
        @sp = add @sp, r8, z = FlagOp::ZERO, n = FlagOp::ZERO, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 16
      when 0xE9
        @pc = @memory[self.hl].to_u16
        return 4
      when 0xEA
        @memory[d16] = @a
        return 16
        # 0xEB has no functionality
        # 0xEC has no functionality
        # 0xED has no functionality
      when 0xEE
        @a = xor @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 8
      when 0xEF
        raise "FAILED TO MATCH 0xEF"
      when 0xF0
        @a = @memory[0xFF00 + d8]
        return 12
      when 0xF1
        self.af = pop
        return 12
        return 12
      when 0xF2
        @a = @memory[@c]
        return 8
      when 0xF3
        @ime = false
        return 4
        # 0xF4 has no functionality
      when 0xF5
        push self.af
        return 16
        return 16
      when 0xF6
        @a = or @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ZERO, h = FlagOp::ZERO, c = FlagOp::ZERO
        return 8
      when 0xF7
        raise "FAILED TO MATCH 0xF7"
      when 0xF8
        self.hl = @sp + r8
        return 12
      when 0xF9
        @sp = self.hl
        return 8
      when 0xFA
        @a = @memory[d16]
        return 16
      when 0xFB
        @ime = true
        return 4
        # 0xFC has no functionality
        # 0xFD has no functionality
      when 0xFE
        sub @a, @a, z = FlagOp::DEFAULT, n = FlagOp::ONE, h = FlagOp::DEFAULT, c = FlagOp::DEFAULT
        return 8
      when 0xFF
        raise "FAILED TO MATCH 0xFF"
      end
    else
      case opcode
      when 0x00
        raise "FAILED TO MATCH CB-0x00"
        return 8
      when 0x01
        raise "FAILED TO MATCH CB-0x01"
        return 8
      when 0x02
        raise "FAILED TO MATCH CB-0x02"
        return 8
      when 0x03
        raise "FAILED TO MATCH CB-0x03"
        return 8
      when 0x04
        raise "FAILED TO MATCH CB-0x04"
        return 8
      when 0x05
        raise "FAILED TO MATCH CB-0x05"
        return 8
      when 0x06
        raise "FAILED TO MATCH CB-0x06"
        return 16
      when 0x07
        raise "FAILED TO MATCH CB-0x07"
        return 8
      when 0x08
        raise "FAILED TO MATCH CB-0x08"
        return 8
      when 0x09
        raise "FAILED TO MATCH CB-0x09"
        return 8
      when 0x0A
        raise "FAILED TO MATCH CB-0x0A"
        return 8
      when 0x0B
        raise "FAILED TO MATCH CB-0x0B"
        return 8
      when 0x0C
        raise "FAILED TO MATCH CB-0x0C"
        return 8
      when 0x0D
        raise "FAILED TO MATCH CB-0x0D"
        return 8
      when 0x0E
        raise "FAILED TO MATCH CB-0x0E"
        return 16
      when 0x0F
        raise "FAILED TO MATCH CB-0x0F"
        return 8
      when 0x10
        raise "FAILED TO MATCH CB-0x10"
        return 8
      when 0x11
        raise "FAILED TO MATCH CB-0x11"
        return 8
      when 0x12
        raise "FAILED TO MATCH CB-0x12"
        return 8
      when 0x13
        raise "FAILED TO MATCH CB-0x13"
        return 8
      when 0x14
        raise "FAILED TO MATCH CB-0x14"
        return 8
      when 0x15
        raise "FAILED TO MATCH CB-0x15"
        return 8
      when 0x16
        raise "FAILED TO MATCH CB-0x16"
        return 16
      when 0x17
        raise "FAILED TO MATCH CB-0x17"
        return 8
      when 0x18
        raise "FAILED TO MATCH CB-0x18"
        return 8
      when 0x19
        raise "FAILED TO MATCH CB-0x19"
        return 8
      when 0x1A
        raise "FAILED TO MATCH CB-0x1A"
        return 8
      when 0x1B
        raise "FAILED TO MATCH CB-0x1B"
        return 8
      when 0x1C
        raise "FAILED TO MATCH CB-0x1C"
        return 8
      when 0x1D
        raise "FAILED TO MATCH CB-0x1D"
        return 8
      when 0x1E
        raise "FAILED TO MATCH CB-0x1E"
        return 16
      when 0x1F
        raise "FAILED TO MATCH CB-0x1F"
        return 8
      when 0x20
        raise "FAILED TO MATCH CB-0x20"
        return 8
      when 0x21
        raise "FAILED TO MATCH CB-0x21"
        return 8
      when 0x22
        raise "FAILED TO MATCH CB-0x22"
        return 8
      when 0x23
        raise "FAILED TO MATCH CB-0x23"
        return 8
      when 0x24
        raise "FAILED TO MATCH CB-0x24"
        return 8
      when 0x25
        raise "FAILED TO MATCH CB-0x25"
        return 8
      when 0x26
        raise "FAILED TO MATCH CB-0x26"
        return 16
      when 0x27
        raise "FAILED TO MATCH CB-0x27"
        return 8
      when 0x28
        raise "FAILED TO MATCH CB-0x28"
        return 8
      when 0x29
        raise "FAILED TO MATCH CB-0x29"
        return 8
      when 0x2A
        raise "FAILED TO MATCH CB-0x2A"
        return 8
      when 0x2B
        raise "FAILED TO MATCH CB-0x2B"
        return 8
      when 0x2C
        raise "FAILED TO MATCH CB-0x2C"
        return 8
      when 0x2D
        raise "FAILED TO MATCH CB-0x2D"
        return 8
      when 0x2E
        raise "FAILED TO MATCH CB-0x2E"
        return 16
      when 0x2F
        raise "FAILED TO MATCH CB-0x2F"
        return 8
      when 0x30
        raise "FAILED TO MATCH CB-0x30"
        return 8
      when 0x31
        raise "FAILED TO MATCH CB-0x31"
        return 8
      when 0x32
        raise "FAILED TO MATCH CB-0x32"
        return 8
      when 0x33
        raise "FAILED TO MATCH CB-0x33"
        return 8
      when 0x34
        raise "FAILED TO MATCH CB-0x34"
        return 8
      when 0x35
        raise "FAILED TO MATCH CB-0x35"
        return 8
      when 0x36
        raise "FAILED TO MATCH CB-0x36"
        return 16
      when 0x37
        raise "FAILED TO MATCH CB-0x37"
        return 8
      when 0x38
        raise "FAILED TO MATCH CB-0x38"
        return 8
      when 0x39
        raise "FAILED TO MATCH CB-0x39"
        return 8
      when 0x3A
        raise "FAILED TO MATCH CB-0x3A"
        return 8
      when 0x3B
        raise "FAILED TO MATCH CB-0x3B"
        return 8
      when 0x3C
        raise "FAILED TO MATCH CB-0x3C"
        return 8
      when 0x3D
        raise "FAILED TO MATCH CB-0x3D"
        return 8
      when 0x3E
        raise "FAILED TO MATCH CB-0x3E"
        return 16
      when 0x3F
        raise "FAILED TO MATCH CB-0x3F"
        return 8
      when 0x40
        bit @b, 0
        return 8
      when 0x41
        bit @c, 0
        return 8
      when 0x42
        bit @d, 0
        return 8
      when 0x43
        bit @e, 0
        return 8
      when 0x44
        bit @h, 0
        return 8
      when 0x45
        bit @l, 0
        return 8
      when 0x46
        bit @memory[self.hl], 0
        return 16
      when 0x47
        bit @a, 0
        return 8
      when 0x48
        bit @b, 1
        return 8
      when 0x49
        bit @c, 1
        return 8
      when 0x4A
        bit @d, 1
        return 8
      when 0x4B
        bit @e, 1
        return 8
      when 0x4C
        bit @h, 1
        return 8
      when 0x4D
        bit @l, 1
        return 8
      when 0x4E
        bit @memory[self.hl], 1
        return 16
      when 0x4F
        bit @a, 1
        return 8
      when 0x50
        bit @b, 2
        return 8
      when 0x51
        bit @c, 2
        return 8
      when 0x52
        bit @d, 2
        return 8
      when 0x53
        bit @e, 2
        return 8
      when 0x54
        bit @h, 2
        return 8
      when 0x55
        bit @l, 2
        return 8
      when 0x56
        bit @memory[self.hl], 2
        return 16
      when 0x57
        bit @a, 2
        return 8
      when 0x58
        bit @b, 3
        return 8
      when 0x59
        bit @c, 3
        return 8
      when 0x5A
        bit @d, 3
        return 8
      when 0x5B
        bit @e, 3
        return 8
      when 0x5C
        bit @h, 3
        return 8
      when 0x5D
        bit @l, 3
        return 8
      when 0x5E
        bit @memory[self.hl], 3
        return 16
      when 0x5F
        bit @a, 3
        return 8
      when 0x60
        bit @b, 4
        return 8
      when 0x61
        bit @c, 4
        return 8
      when 0x62
        bit @d, 4
        return 8
      when 0x63
        bit @e, 4
        return 8
      when 0x64
        bit @h, 4
        return 8
      when 0x65
        bit @l, 4
        return 8
      when 0x66
        bit @memory[self.hl], 4
        return 16
      when 0x67
        bit @a, 4
        return 8
      when 0x68
        bit @b, 5
        return 8
      when 0x69
        bit @c, 5
        return 8
      when 0x6A
        bit @d, 5
        return 8
      when 0x6B
        bit @e, 5
        return 8
      when 0x6C
        bit @h, 5
        return 8
      when 0x6D
        bit @l, 5
        return 8
      when 0x6E
        bit @memory[self.hl], 5
        return 16
      when 0x6F
        bit @a, 5
        return 8
      when 0x70
        bit @b, 6
        return 8
      when 0x71
        bit @c, 6
        return 8
      when 0x72
        bit @d, 6
        return 8
      when 0x73
        bit @e, 6
        return 8
      when 0x74
        bit @h, 6
        return 8
      when 0x75
        bit @l, 6
        return 8
      when 0x76
        bit @memory[self.hl], 6
        return 16
      when 0x77
        bit @a, 6
        return 8
      when 0x78
        bit @b, 7
        return 8
      when 0x79
        bit @c, 7
        return 8
      when 0x7A
        bit @d, 7
        return 8
      when 0x7B
        bit @e, 7
        return 8
      when 0x7C
        bit @h, 7
        return 8
      when 0x7D
        bit @l, 7
        return 8
      when 0x7E
        bit @memory[self.hl], 7
        return 16
      when 0x7F
        bit @a, 7
        return 8
      when 0x80
        raise "FAILED TO MATCH CB-0x80"
        return 8
      when 0x81
        raise "FAILED TO MATCH CB-0x81"
        return 8
      when 0x82
        raise "FAILED TO MATCH CB-0x82"
        return 8
      when 0x83
        raise "FAILED TO MATCH CB-0x83"
        return 8
      when 0x84
        raise "FAILED TO MATCH CB-0x84"
        return 8
      when 0x85
        raise "FAILED TO MATCH CB-0x85"
        return 8
      when 0x86
        raise "FAILED TO MATCH CB-0x86"
        return 16
      when 0x87
        raise "FAILED TO MATCH CB-0x87"
        return 8
      when 0x88
        raise "FAILED TO MATCH CB-0x88"
        return 8
      when 0x89
        raise "FAILED TO MATCH CB-0x89"
        return 8
      when 0x8A
        raise "FAILED TO MATCH CB-0x8A"
        return 8
      when 0x8B
        raise "FAILED TO MATCH CB-0x8B"
        return 8
      when 0x8C
        raise "FAILED TO MATCH CB-0x8C"
        return 8
      when 0x8D
        raise "FAILED TO MATCH CB-0x8D"
        return 8
      when 0x8E
        raise "FAILED TO MATCH CB-0x8E"
        return 16
      when 0x8F
        raise "FAILED TO MATCH CB-0x8F"
        return 8
      when 0x90
        raise "FAILED TO MATCH CB-0x90"
        return 8
      when 0x91
        raise "FAILED TO MATCH CB-0x91"
        return 8
      when 0x92
        raise "FAILED TO MATCH CB-0x92"
        return 8
      when 0x93
        raise "FAILED TO MATCH CB-0x93"
        return 8
      when 0x94
        raise "FAILED TO MATCH CB-0x94"
        return 8
      when 0x95
        raise "FAILED TO MATCH CB-0x95"
        return 8
      when 0x96
        raise "FAILED TO MATCH CB-0x96"
        return 16
      when 0x97
        raise "FAILED TO MATCH CB-0x97"
        return 8
      when 0x98
        raise "FAILED TO MATCH CB-0x98"
        return 8
      when 0x99
        raise "FAILED TO MATCH CB-0x99"
        return 8
      when 0x9A
        raise "FAILED TO MATCH CB-0x9A"
        return 8
      when 0x9B
        raise "FAILED TO MATCH CB-0x9B"
        return 8
      when 0x9C
        raise "FAILED TO MATCH CB-0x9C"
        return 8
      when 0x9D
        raise "FAILED TO MATCH CB-0x9D"
        return 8
      when 0x9E
        raise "FAILED TO MATCH CB-0x9E"
        return 16
      when 0x9F
        raise "FAILED TO MATCH CB-0x9F"
        return 8
      when 0xA0
        raise "FAILED TO MATCH CB-0xA0"
        return 8
      when 0xA1
        raise "FAILED TO MATCH CB-0xA1"
        return 8
      when 0xA2
        raise "FAILED TO MATCH CB-0xA2"
        return 8
      when 0xA3
        raise "FAILED TO MATCH CB-0xA3"
        return 8
      when 0xA4
        raise "FAILED TO MATCH CB-0xA4"
        return 8
      when 0xA5
        raise "FAILED TO MATCH CB-0xA5"
        return 8
      when 0xA6
        raise "FAILED TO MATCH CB-0xA6"
        return 16
      when 0xA7
        raise "FAILED TO MATCH CB-0xA7"
        return 8
      when 0xA8
        raise "FAILED TO MATCH CB-0xA8"
        return 8
      when 0xA9
        raise "FAILED TO MATCH CB-0xA9"
        return 8
      when 0xAA
        raise "FAILED TO MATCH CB-0xAA"
        return 8
      when 0xAB
        raise "FAILED TO MATCH CB-0xAB"
        return 8
      when 0xAC
        raise "FAILED TO MATCH CB-0xAC"
        return 8
      when 0xAD
        raise "FAILED TO MATCH CB-0xAD"
        return 8
      when 0xAE
        raise "FAILED TO MATCH CB-0xAE"
        return 16
      when 0xAF
        raise "FAILED TO MATCH CB-0xAF"
        return 8
      when 0xB0
        raise "FAILED TO MATCH CB-0xB0"
        return 8
      when 0xB1
        raise "FAILED TO MATCH CB-0xB1"
        return 8
      when 0xB2
        raise "FAILED TO MATCH CB-0xB2"
        return 8
      when 0xB3
        raise "FAILED TO MATCH CB-0xB3"
        return 8
      when 0xB4
        raise "FAILED TO MATCH CB-0xB4"
        return 8
      when 0xB5
        raise "FAILED TO MATCH CB-0xB5"
        return 8
      when 0xB6
        raise "FAILED TO MATCH CB-0xB6"
        return 16
      when 0xB7
        raise "FAILED TO MATCH CB-0xB7"
        return 8
      when 0xB8
        raise "FAILED TO MATCH CB-0xB8"
        return 8
      when 0xB9
        raise "FAILED TO MATCH CB-0xB9"
        return 8
      when 0xBA
        raise "FAILED TO MATCH CB-0xBA"
        return 8
      when 0xBB
        raise "FAILED TO MATCH CB-0xBB"
        return 8
      when 0xBC
        raise "FAILED TO MATCH CB-0xBC"
        return 8
      when 0xBD
        raise "FAILED TO MATCH CB-0xBD"
        return 8
      when 0xBE
        raise "FAILED TO MATCH CB-0xBE"
        return 16
      when 0xBF
        raise "FAILED TO MATCH CB-0xBF"
        return 8
      when 0xC0
        raise "FAILED TO MATCH CB-0xC0"
        return 8
      when 0xC1
        raise "FAILED TO MATCH CB-0xC1"
        return 8
      when 0xC2
        raise "FAILED TO MATCH CB-0xC2"
        return 8
      when 0xC3
        raise "FAILED TO MATCH CB-0xC3"
        return 8
      when 0xC4
        raise "FAILED TO MATCH CB-0xC4"
        return 8
      when 0xC5
        raise "FAILED TO MATCH CB-0xC5"
        return 8
      when 0xC6
        raise "FAILED TO MATCH CB-0xC6"
        return 16
      when 0xC7
        raise "FAILED TO MATCH CB-0xC7"
        return 8
      when 0xC8
        raise "FAILED TO MATCH CB-0xC8"
        return 8
      when 0xC9
        raise "FAILED TO MATCH CB-0xC9"
        return 8
      when 0xCA
        raise "FAILED TO MATCH CB-0xCA"
        return 8
      when 0xCB
        raise "FAILED TO MATCH CB-0xCB"
        return 8
      when 0xCC
        raise "FAILED TO MATCH CB-0xCC"
        return 8
      when 0xCD
        raise "FAILED TO MATCH CB-0xCD"
        return 8
      when 0xCE
        raise "FAILED TO MATCH CB-0xCE"
        return 16
      when 0xCF
        raise "FAILED TO MATCH CB-0xCF"
        return 8
      when 0xD0
        raise "FAILED TO MATCH CB-0xD0"
        return 8
      when 0xD1
        raise "FAILED TO MATCH CB-0xD1"
        return 8
      when 0xD2
        raise "FAILED TO MATCH CB-0xD2"
        return 8
      when 0xD3
        raise "FAILED TO MATCH CB-0xD3"
        return 8
      when 0xD4
        raise "FAILED TO MATCH CB-0xD4"
        return 8
      when 0xD5
        raise "FAILED TO MATCH CB-0xD5"
        return 8
      when 0xD6
        raise "FAILED TO MATCH CB-0xD6"
        return 16
      when 0xD7
        raise "FAILED TO MATCH CB-0xD7"
        return 8
      when 0xD8
        raise "FAILED TO MATCH CB-0xD8"
        return 8
      when 0xD9
        raise "FAILED TO MATCH CB-0xD9"
        return 8
      when 0xDA
        raise "FAILED TO MATCH CB-0xDA"
        return 8
      when 0xDB
        raise "FAILED TO MATCH CB-0xDB"
        return 8
      when 0xDC
        raise "FAILED TO MATCH CB-0xDC"
        return 8
      when 0xDD
        raise "FAILED TO MATCH CB-0xDD"
        return 8
      when 0xDE
        raise "FAILED TO MATCH CB-0xDE"
        return 16
      when 0xDF
        raise "FAILED TO MATCH CB-0xDF"
        return 8
      when 0xE0
        raise "FAILED TO MATCH CB-0xE0"
        return 8
      when 0xE1
        raise "FAILED TO MATCH CB-0xE1"
        return 8
      when 0xE2
        raise "FAILED TO MATCH CB-0xE2"
        return 8
      when 0xE3
        raise "FAILED TO MATCH CB-0xE3"
        return 8
      when 0xE4
        raise "FAILED TO MATCH CB-0xE4"
        return 8
      when 0xE5
        raise "FAILED TO MATCH CB-0xE5"
        return 8
      when 0xE6
        raise "FAILED TO MATCH CB-0xE6"
        return 16
      when 0xE7
        raise "FAILED TO MATCH CB-0xE7"
        return 8
      when 0xE8
        raise "FAILED TO MATCH CB-0xE8"
        return 8
      when 0xE9
        raise "FAILED TO MATCH CB-0xE9"
        return 8
      when 0xEA
        raise "FAILED TO MATCH CB-0xEA"
        return 8
      when 0xEB
        raise "FAILED TO MATCH CB-0xEB"
        return 8
      when 0xEC
        raise "FAILED TO MATCH CB-0xEC"
        return 8
      when 0xED
        raise "FAILED TO MATCH CB-0xED"
        return 8
      when 0xEE
        raise "FAILED TO MATCH CB-0xEE"
        return 16
      when 0xEF
        raise "FAILED TO MATCH CB-0xEF"
        return 8
      when 0xF0
        raise "FAILED TO MATCH CB-0xF0"
        return 8
      when 0xF1
        raise "FAILED TO MATCH CB-0xF1"
        return 8
      when 0xF2
        raise "FAILED TO MATCH CB-0xF2"
        return 8
      when 0xF3
        raise "FAILED TO MATCH CB-0xF3"
        return 8
      when 0xF4
        raise "FAILED TO MATCH CB-0xF4"
        return 8
      when 0xF5
        raise "FAILED TO MATCH CB-0xF5"
        return 8
      when 0xF6
        raise "FAILED TO MATCH CB-0xF6"
        return 16
      when 0xF7
        raise "FAILED TO MATCH CB-0xF7"
        return 8
      when 0xF8
        raise "FAILED TO MATCH CB-0xF8"
        return 8
      when 0xF9
        raise "FAILED TO MATCH CB-0xF9"
        return 8
      when 0xFA
        raise "FAILED TO MATCH CB-0xFA"
        return 8
      when 0xFB
        raise "FAILED TO MATCH CB-0xFB"
        return 8
      when 0xFC
        raise "FAILED TO MATCH CB-0xFC"
        return 8
      when 0xFD
        raise "FAILED TO MATCH CB-0xFD"
        return 8
      when 0xFE
        raise "FAILED TO MATCH CB-0xFE"
        return 16
      when 0xFF
        raise "FAILED TO MATCH CB-0xFF"
        return 8
      end
    end
    raise "MEMES?"
  end
end

OPCODE_LENGTHS = [
  1, 3, 1, 1, 1, 1, 2, 1, 3, 1, 1, 1, 1, 1, 2, 1,
  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
  2, 3, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 2, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 3, 3, 3, 1, 2, 1, 1, 1, 3, 1, 3, 3, 2, 1,
  1, 1, 3, 0, 3, 1, 2, 1, 1, 1, 3, 0, 3, 0, 2, 1,
  2, 1, 1, 0, 0, 1, 2, 1, 2, 1, 3, 0, 0, 0, 2, 1,
  2, 1, 1, 1, 0, 1, 2, 1, 2, 1, 3, 1, 0, 0, 2, 1,
]
