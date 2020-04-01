function xor(v1, v2)
    return (v1 or v2) and not (v1 and v2)
end

function toBool(x)
    if x==0 then
        return false
    end
    return true
end

function decimal_to_binary(dec, size)
    local result={}
    for i=1,size do result[i]=false end
    
    local mod_dec = dec % 2^size
    local i=size
    while mod_dec > 0 do
        local rem = mod_dec % 2
        mod_dec = (mod_dec-rem)/2
        result[i] = toBool(rem)
        i = i - 1
    end
    
    return result
end

function bitwise_not(n1)
    local result={}
    for k,v in ipairs(n1.bits) do
        result[k]=not v
    end
    return binary(result, n1.size)
end



binary_mt = {
    __add = function(n1, n2)
        local size = math.max(n1.size, n2.size)
        local result={}
        local carry=false
        
        for k = size,1,-1 do
            local v1 = n1.bits[k+(n1.size-size)]
            local v2 = n2.bits[k+(n2.size-size)]
            
            if v2==nil then v2=false end
            
            local h_add = xor(v1, v2)
            local r = xor(h_add, carry)
            result[k]=r
            carry = (v1 and v2) or (carry and h_add)
        end
        
        return binary(result)
    end,
    __sub = function(n1, n2)
        local size = math.max(n1.size, n2.size)
        return n1.to_size(size)+n2.to_size(size).complement()
    end,
    __mul = function(n1, n2)
        local addition = binary(0, 2*n1.size)
        
        for i=1,n2.size do
            if n2.bits[n2.size-i+1] then
                addition = addition + n1.shift_left(i-1)
            end
        end
        
        return addition
    end,
    __div = function(n1, n2)
        local result = {}
        
        local dividend = n1
        local divisor = n2
        local rem = binary({})
        
        for i=1,n1.size do
            
            rem = rem.shift_left(1) + binary({dividend.bits[i]})
            
            if divisor <= rem then
                result[i]=true
                rem = rem - divisor
            else
                result[i]=false
            end
            
        end
        
        return binary(result)
    end,
    __lt = function(n1, n2)
        local size = math.max(n1.size, n2.size)
        local n1_off=size-n1.size 
        local n2_off=size-n2.size
        for i=1,size do
            local n1_bit = n1.bits[i-n1_off]
            local n2_bit = n2.bits[i-n2_off]
            if n1_bit==true and (n2_bit==false or n2_bit==nil) then return false end
            if (n1_bit==false or n1_bit==nil) and n2_bit==true then return true end
        end
        return false
    end,
    __le = function(n1, n2)
        local size = math.max(n1.size, n2.size)
        local n1_off=size-n1.size 
        local n2_off=size-n2.size
        for i=1,size do
            local n1_bit = n1.bits[i-n1_off]
            local n2_bit = n2.bits[i-n2_off]
            if n1_bit==true and (n2_bit==false or n2_bit==nil) then return false end
            if (n1_bit==false or n1_bit==nil) and n2_bit==true then return true end
        end
        return true
    end,
    __eq = function(n1, n2)
        local size = math.max(n1.size, n2.size)
        local n1_off=size-n1.size 
        local n2_off=size-n2.size
        for i=1,size do
            local n1_bit = n1.bits[i-n1_off]
            local n2_bit = n2.bits[i-n2_off]
            if n1_bit==true and (n2_bit==false or n2_bit==nil) then return false end
            if n2_bit==true and (n1_bit==false or n1_bit==nil) then return false end
        end
        return true
    end,
    __tostring = function(this)
        local bin_str="0b"
        for _,v in ipairs(this.bits) do
            bin_str = bin_str .. (v and "1" or "0")
        end
        return bin_str
    end
}

function binary(value, size)  -- You can initialize with a table of booleans (and an optional size), or you can initialize with a decimal number and a size parameter
    
    local this
    
    if type(value) == "table" then
        
        if size then
            
            if size>#value then
                
                local result = {}
                local diff=size-#value
                
                for i=1, size do
                    if i<=diff then
                        result[i]=false
                    else
                        result[i]=value[i-diff]
                    end
                end
                
                this={bits=result, size=size}
                
            elseif size<#value then
                
                local result = {}
                local diff=size-#value
                
                for i=1,size do
                    if i<=diff then
                        result[i]=false
                    else
                        result[i]=value[i-diff]
                    end
                end
                
                this={bits=result, size=size}
                
            else
                this={bits=value, size=size}
            end
        
        else
            this={bits=value, size=#value}
        end
        
    else
        this={bits=decimal_to_binary(value, size), size=size}
    end
    
    setmetatable(this, binary_mt)
    
    this.complement = function()
        return bitwise_not(this)+binary({true}, this.size)
    end
    
    this.to_dec = function()
        local value=0
        for k = 1,this.size do
            if this.bits[k] then value = value + 2^(this.size-k) end
        end
        return value
    end
    
    this.extend_sign = function(size)
        local result = {}
        local sign = this.bits[1]
        for i=1,size do
            if i<=size-this.size then
                result[i] = sign
            else
                result[i] = this.bits[i+this.size-size]
            end
        end
        return binary(result)
    end
    
    this.shift_right = function(n)
        local result = {}
        for i=1,this.size-n do
            result[i]=this.bits[i]
        end
        return binary(result)
    end
    
    this.shift_left = function(n)
        local result = {}
        for i=1,this.size+n do
            if i<=this.size then
                result[i]=this.bits[i]
            else
                result[i]=false
            end
        end
        return binary(result)
    end
    
    this.move_right = function(n)
    end
    
    this.move_left = function(n)
        local result = {}
        for i=1, this.size do
            if i<=this.size-n then
                result[i]=this.bits[i+n]
            else
                result[i] = false
            end
        end
        return binary(result)
    end
    
    this.to_size = function(size)
        return binary(this.bits, size)
    end
    
    return this
end



PICO8_MODULO_ADJUSTMENT = true

DECIMAL_PRECISION = 16
INTEGER_PRECISION = 16
TOTAL_SIZE = DECIMAL_PRECISION+INTEGER_PRECISION

fixed_mt = {
    __add = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        return fixedpoint(n1.binary+n2.binary)
    end,
    __sub = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        return fixedpoint(n1.binary-n2.binary)
    end,
    __mul = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        local n1_extended = n1.binary.extend_sign(TOTAL_SIZE*2)
        local n2_extended = n2.binary.extend_sign(TOTAL_SIZE*2)
        local result = fixedpoint((n1_extended * n2_extended).shift_right(DECIMAL_PRECISION))
        
        return result
    end,
    __div = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        local n1_abs = n1.binary
        local n2_abs = n2.binary
        
        local n1_sign = n1.negative
        local n2_sign = n2.negative
        
        if n1_sign then
            n1_abs = n1.binary.complement()
        end
        
        if n2_sign then
            n2_abs = n2.binary.complement()
        end
        
        if xor(n1_sign, n2_sign) then
            return fixedpoint((n1_abs.shift_left(DECIMAL_PRECISION)/n2_abs).complement())
        else
            return fixedpoint(n1_abs.shift_left(DECIMAL_PRECISION)/n2_abs)
        end
    end,
    __unm = function(this)
        return fixedpoint(this.binary.complement())
    end,
    __mod = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        local modulo = n1 - (n1/n2).floor() * n2
        if PICO8_MODULO_ADJUSTMENT and modulo.negative then
            return modulo - n2
        end
        return modulo
    end,
    __lt = function(n1, n2) 
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        if n1.negative and not n2.negative then
            return true
        elseif not n1.negative and n2.negative then
            return false
        else
            return n1.binary<n2.binary
        end
    end,
    __le = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        if n1.negative and not n2.negative then
            return true
        elseif not n1.negative and n2.negative then
            return false
        else
            return n1.binary<=n2.binary
        end
    end,
    __eq = function(n1, n2)
		n1=fixedpoint(n1)
		n2=fixedpoint(n2)
        return n1.binary==n2.binary
    end,
    __tostring = function(this)
        return this.floating()
    end,
	__concat = function(s1,s2)
		return tostring(s1)..tostring(s2)
	end
}

function fixedpoint(value)  --You can initialize with a number or a binary object
    local this
    
    if type(value) == "table" then
        if getmetatable(value)==fixed_mt then 
			return value 
		end
        local result = binary(value.bits, TOTAL_SIZE)
        
        this = {binary=result, negative=result.bits[1]}
        
    else
        local mod_val = value % 2^INTEGER_PRECISION
        this = {binary=binary(value * 2^DECIMAL_PRECISION, TOTAL_SIZE), negative = mod_val>=2^(INTEGER_PRECISION)/2}
    end
    
    setmetatable(this, fixed_mt)
    
    this.floor = function()
        local new = {}
        for i=1,TOTAL_SIZE do
            if i<=INTEGER_PRECISION then
                new[i]=this.binary.bits[i]
            else
                new[i]=false
            end
        end
        return fixedpoint(binary(new, TOTAL_SIZE))
    end
    
    this.ceil = function()
        local m = binary({true}, DECIMAL_PRECISION).complement()
        return (this+fixedpoint(m)).floor()
    end
    
    this.floating = function()
        local dec = this.binary.to_dec() / 2^DECIMAL_PRECISION
        if this.negative then
            return dec-2^INTEGER_PRECISION
        end
        return dec
    end
    
    return this
end
print(fixedpoint(fixedpoint(3))==fixedpoint(3))
return fixedpoint