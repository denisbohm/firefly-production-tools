//
//  FDExecutable.m
//  Sync
//
//  Created by Denis Bohm on 4/26/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDExecutable.h"

#include <dwarf.h>
#include <gelf.h>
#include <libelf.h>
#include <libdwarf.h>

struct srcfilesdata {
    char ** srcfiles;
    Dwarf_Signed srcfilescount;
    int srcfilesres;
};


@implementation FDExecutableFunction
@end

@implementation FDExecutableSection
@end

@interface FDExecutable ()
@end

@implementation FDExecutable

- (id)init
{
    if (self = [super init]) {
        _sections = [NSArray array];
        _functions = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)read_cu_list:(Dwarf_Debug) dbg
{
    Dwarf_Unsigned cu_header_length = 0;
    Dwarf_Half version_stamp = 0;
    Dwarf_Unsigned abbrev_offset = 0;
    Dwarf_Half address_size = 0;
    Dwarf_Unsigned next_cu_header = 0;
    Dwarf_Error error;
    int cu_number = 0;
    
    for(;;++cu_number) {
        struct srcfilesdata sf;
        sf.srcfilesres = DW_DLV_ERROR;
        sf.srcfiles = 0;
        sf.srcfilescount = 0;
        Dwarf_Die no_die = 0;
        Dwarf_Die cu_die = 0;
        int res = DW_DLV_ERROR;
        res = dwarf_next_cu_header(dbg,&cu_header_length,
                                   &version_stamp, &abbrev_offset, &address_size,
                                   &next_cu_header, &error);
        if(res == DW_DLV_ERROR) {
            @throw [NSException exceptionWithName:@"DWARF Error" reason:@"Error in dwarf_next_cu_header" userInfo:nil];
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Done. */
            return;
        }
        /* The CU will have a single sibling, a cu_die. */
        res = dwarf_siblingof(dbg,no_die,&cu_die,&error);
        if(res == DW_DLV_ERROR) {
            @throw [NSException exceptionWithName:@"DWARF Error" reason:@"Error in dwarf_siblingof on CU die" userInfo:nil];
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Impossible case. */
            @throw [NSException exceptionWithName:@"DWARF Error" reason:@"no entry! in dwarf_siblingof on CU die" userInfo:nil];
        }
        [self get_die_and_siblings:dbg in_die:cu_die in_level:0 sf:&sf];
        dwarf_dealloc(dbg,cu_die,DW_DLA_DIE);
        [self resetsrcfiles:dbg sf:&sf];
    }
}

- (void)get_die_and_siblings:(Dwarf_Debug)dbg in_die:(Dwarf_Die)in_die in_level:(int)in_level sf:(struct srcfilesdata *)sf
{
    int res = DW_DLV_ERROR;
    Dwarf_Die cur_die=in_die;
    Dwarf_Die child = 0;
    Dwarf_Error error;
    
    [self print_die_data:dbg in_die:in_die in_level:in_level sf:sf];
    
    for(;;) {
        Dwarf_Die sib_die = 0;
        res = dwarf_child(cur_die,&child,&error);
        if(res == DW_DLV_ERROR) {
            @throw [NSException exceptionWithName:@"DWARF Error"
                                           reason:[NSString stringWithFormat:@"Error in dwarf_child , level %d",in_level]
                                         userInfo:nil];
        }
        if(res == DW_DLV_OK) {
            [self get_die_and_siblings:dbg in_die:child in_level:in_level+1 sf:sf];
        }
        /* res == DW_DLV_NO_ENTRY */
        res = dwarf_siblingof(dbg,cur_die,&sib_die,&error);
        if(res == DW_DLV_ERROR) {
            @throw [NSException exceptionWithName:@"DWARF Error"
                                           reason:[NSString stringWithFormat:@"Error in dwarf_siblingof , level %d",in_level]
                                         userInfo:nil];
        }
        if(res == DW_DLV_NO_ENTRY) {
            /* Done at this level. */
            break;
        }
        /* res == DW_DLV_OK */
        if(cur_die != in_die) {
            dwarf_dealloc(dbg,cur_die,DW_DLA_DIE);
        }
        cur_die = sib_die;
        [self print_die_data:dbg in_die:cur_die in_level:in_level sf:sf];
    }
    return;
}

- (void)get_addr:(Dwarf_Attribute)attr val:(Dwarf_Addr *)val
{
    Dwarf_Error error = 0;
    int res;
    Dwarf_Addr uval = 0;
    res = dwarf_formaddr(attr,&uval,&error);
    if(res == DW_DLV_OK) {
        *val = uval;
        return;
    }
    return;
}

- (void)get_number:(Dwarf_Attribute)attr val:(Dwarf_Unsigned *)val
{
    Dwarf_Error error = 0;
    int res;
    Dwarf_Signed sval = 0;
    Dwarf_Unsigned uval = 0;
    res = dwarf_formudata(attr,&uval,&error);
    if(res == DW_DLV_OK) {
        *val = uval;
        return;
    }
    res = dwarf_formsdata(attr,&sval,&error);
    if(res == DW_DLV_OK) {
        *val = sval;
        return;
    }
    return;
}

- (void)print_subprog:(Dwarf_Debug)dbg name:(char *)name die:(Dwarf_Die)die level:(int)level sf:(struct srcfilesdata *)sf
{
    int res;
    Dwarf_Error error = 0;
    Dwarf_Attribute *attrbuf = 0;
    Dwarf_Addr lowpc = 0;
    Dwarf_Addr highpc = 0;
    Dwarf_Signed attrcount = 0;
    Dwarf_Unsigned i;
    Dwarf_Unsigned filenum = 0;
    Dwarf_Unsigned linenum = 0;
    char *filename = 0;
    res = dwarf_attrlist(die,&attrbuf,&attrcount,&error);
    if(res != DW_DLV_OK) {
        return;
    }
    for(i = 0; i < attrcount ; ++i) {
        Dwarf_Half aform;
        res = dwarf_whatattr(attrbuf[i],&aform,&error);
        if(res == DW_DLV_OK) {
            if(aform == DW_AT_decl_file) {
                [self get_number:attrbuf[i] val:&filenum];
                if((filenum > 0) && (sf->srcfilescount > (filenum-1))) {
                    filename = sf->srcfiles[filenum-1];
                }
            }
            if(aform == DW_AT_decl_line) {
                [self get_number:attrbuf[i] val:&linenum];
            }
            if(aform == DW_AT_low_pc) {
                [self get_addr:attrbuf[i] val:&lowpc];
            }
            if(aform == DW_AT_high_pc) {
                [self get_addr:attrbuf[i] val:&highpc];
            }
        }
        dwarf_dealloc(dbg,attrbuf[i],DW_DLA_ATTR);
    }

//    NSLog(@"function: %s address: %08llx file: %s line: %lld", name, lowpc, filename ? filename : "", linenum);
        
    FDExecutableFunction *function = [[FDExecutableFunction alloc] init];
    function.name = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
    function.address = lowpc;
    [_functions setObject:function forKey:function.name];
    
    dwarf_dealloc(dbg,attrbuf,DW_DLA_LIST);
}

- (void)print_comp_dir:(Dwarf_Debug)dbg die:(Dwarf_Die)die level:(int)level sf:(struct srcfilesdata *)sf
{
    int res;
    Dwarf_Error error = 0;
    Dwarf_Attribute *attrbuf = 0;
    Dwarf_Signed attrcount = 0;
    Dwarf_Unsigned i;
    res = dwarf_attrlist(die,&attrbuf,&attrcount,&error);
    if(res != DW_DLV_OK) {
        return;
    }
    sf->srcfilesres = dwarf_srcfiles(die,&sf->srcfiles,&sf->srcfilescount,
                                     &error);
    for(i = 0; i < attrcount ; ++i) {
        Dwarf_Half aform;
        res = dwarf_whatattr(attrbuf[i],&aform,&error);
        if(res == DW_DLV_OK) {
            if(aform == DW_AT_comp_dir) {
                char *name = 0;
                res = dwarf_formstring(attrbuf[i],&name,&error);
                if(res == DW_DLV_OK) {
//                    NSLog(@"<%3d> compilation directory : \"%s\"", level,name);
                }
            }
            if(aform == DW_AT_stmt_list) {
                /* Offset of stmt list for this CU in .debug_line */
            }
        }
        dwarf_dealloc(dbg,attrbuf[i],DW_DLA_ATTR);
    }
    dwarf_dealloc(dbg,attrbuf,DW_DLA_LIST);
}

- (void)resetsrcfiles:(Dwarf_Debug)dbg sf:(struct srcfilesdata *)sf
{
    Dwarf_Signed sri = 0;
    for (sri = 0; sri < sf->srcfilescount; ++sri) {
        dwarf_dealloc(dbg, sf->srcfiles[sri], DW_DLA_STRING);
    }
    dwarf_dealloc(dbg, sf->srcfiles, DW_DLA_LIST);
    sf->srcfilesres = DW_DLV_ERROR;
    sf->srcfiles = 0;
    sf->srcfilescount = 0;
}

- (void)print_die_data:(Dwarf_Debug)dbg in_die:(Dwarf_Die)print_me in_level:(int)level sf:(struct srcfilesdata *)sf
{
    char *name = 0;
    Dwarf_Error error = 0;
    Dwarf_Half tag = 0;
    const char *tagname = 0;
    int localname = 0;
    
    int res = dwarf_diename(print_me,&name,&error);
    
    if(res == DW_DLV_ERROR) {
        @throw [NSException exceptionWithName:@"DWARF Error"
                                       reason:[NSString stringWithFormat:@"Error in dwarf_diename , level %d",level]
                                     userInfo:nil];
    }
    if(res == DW_DLV_NO_ENTRY) {
        name = "<no DW_AT_name attr>";
        localname = 1;
    }
    res = dwarf_tag(print_me,&tag,&error);
    if(res != DW_DLV_OK) {
        @throw [NSException exceptionWithName:@"DWARF Error"
                                       reason:[NSString stringWithFormat:@"Error in dwarf_tag , level %d",level]
                                     userInfo:nil];
    }
    res = dwarf_get_TAG_name(tag,&tagname);
    if(res != DW_DLV_OK) {
        @throw [NSException exceptionWithName:@"DWARF Error"
                                       reason:[NSString stringWithFormat:@"Error in dwarf_get_TAG_name , level %d",level]
                                     userInfo:nil];
    }
    bool namesoptionon = true;
    if(namesoptionon) {
        if( tag == DW_TAG_subprogram) {
//            NSLog(@"<%3d> subprogram            : \"%s\"",level,name);
            [self print_subprog:dbg name:name die:print_me level:level sf:sf];
        } else if (tag == DW_TAG_compile_unit || tag == DW_TAG_partial_unit || tag == DW_TAG_type_unit) {
            [self resetsrcfiles:dbg sf:sf];
//            NSLog(@"<%3d> source file           : \"%s\"",level,name);
            [self print_comp_dir:dbg die:print_me level:level sf:sf];
        }
    }
    if(!localname) {
        dwarf_dealloc(dbg,name,DW_DLA_STRING);
    }
}

- (void)loadSymbols:(const char *)filename
{
    int fd;
    if ((fd = open(filename, O_RDONLY, 0)) < 0) {
        @throw [NSException exceptionWithName:@"DWARF Error"
                                       reason:[NSString stringWithFormat:@"open \%s\" failed", filename]
                                     userInfo:nil];
    }
    Dwarf_Handler errhand = 0;
    Dwarf_Ptr errarg = 0;
    Dwarf_Debug dbg = 0;
    Dwarf_Error error;
    int res = dwarf_init(fd, DW_DLC_READ, errhand, errarg, &dbg, &error);
    if (res != DW_DLV_OK) {
        @throw [NSException exceptionWithName:@"DWARF Error"
                                       reason:@"Giving up, cannot do DWARF processing"
                                     userInfo:nil];
    }
    
    @try {
        [self read_cu_list:dbg];
    } @finally {
        dwarf_finish(dbg, &error);
        close(fd);
    }
}

- (void)loadProgram:(const char *)filename
{
    if (elf_version(EV_CURRENT) == EV_NONE) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"ELF library initialization failed: %s", elf_errmsg(-1)]
                                     userInfo:nil];
    }
    int fd;
    if ((fd = open(filename, O_RDONLY, 0)) < 0) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"open \%s\" failed", filename]
                                     userInfo:nil];
    }
    Elf *e;
    if ((e = elf_begin(fd, ELF_C_READ , NULL)) == NULL) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"elf_begin() failed: %s.", elf_errmsg(-1)]
                                     userInfo:nil];
    }
    
    Elf_Kind kind = elf_kind(e);
    if (kind != ELF_K_ELF) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:@"elf_kind != ELF_K_ELF"
                                     userInfo:nil];
    }
    
    
    NSMutableDictionary *sectionByAddress = [NSMutableDictionary dictionary];
    size_t shstrndx;
    if (elf_getshdrstrndx(e, &shstrndx) != 0) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"getshstrndx() failed: %s.", elf_errmsg(-1)]
                                     userInfo:nil];
    }
    Elf_Scn *scn = NULL;
    while ((scn = elf_nextscn(e, scn)) != NULL) {
        GElf_Shdr shdr;
        if (gelf_getshdr(scn, &shdr) != &shdr) {
            @throw [NSException exceptionWithName:@"ELF Error"
                                           reason:[NSString stringWithFormat:@"getshdr() failed: %s.",
                 elf_errmsg(-1)]
                                         userInfo:nil];
        }
        if (shdr.sh_type != SHT_PROGBITS) {
            continue;
        }
        if ((shdr.sh_flags & SHF_ALLOC) == 0) {
            continue;
        }
        
        uint32_t address = (uint32_t)shdr.sh_addr;
        
        char *name;
        if ((name = elf_strptr(e, shstrndx, shdr.sh_name)) == NULL) {
            @throw [NSException exceptionWithName:@"ELF Error"
                                           reason:[NSString stringWithFormat:@"elf_strptr() failed: %s.",
                 elf_errmsg(-1)]
                                         userInfo:nil];
        }
        
        NSMutableData *sectionData = [NSMutableData data];
        Elf_Data *data = NULL;
        size_t n = 0;
        while (n < shdr.sh_size && (data = elf_getdata(scn, data)) != NULL) {
            [sectionData appendBytes:(uint8_t *)data->d_buf length:data->d_size];
            n += data->d_size;
        }

        NSLog(@"Section %-4.4jd %s %08x %ld", (uintmax_t) elf_ndxscn(scn), name, address, sectionData.length);
        
        FDExecutableSection *section = [[FDExecutableSection alloc] init];
        section.type = FDExecutableSectionTypeProgram;
        section.address = address;
        section.data = sectionData;
        NSNumber *key = [NSNumber numberWithLong:address];
        [sectionByAddress setObject:section forKey:key];
    }
    
    
    
    GElf_Ehdr ehdr;
    if (gelf_getehdr(e, &ehdr) == NULL) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"getehdr() failed: %s.", elf_errmsg(-1)]
                                     userInfo:nil];
    }
    
    size_t n;
    if (elf_getphdrnum(e, &n) != 0) {
        @throw [NSException exceptionWithName:@"ELF Error"
                                       reason:[NSString stringWithFormat:@"elf_getphnum() failed: %s.", elf_errmsg(-1)]
                                     userInfo:nil];
    }
    for (int i = 0; i < n; i++) {
        GElf_Phdr phdr;
        if (gelf_getphdr(e, i, &phdr) != &phdr) {
            @throw [NSException exceptionWithName:@"ELF Error"
                                           reason:[NSString stringWithFormat:@"getphdr() failed: %s.", elf_errmsg(-1)]
                                         userInfo:nil];
        }
        if (phdr.p_type != PT_LOAD) {
            continue;
        }
        if (phdr.p_vaddr == phdr.p_paddr) {
            continue;
        }

        /*
        lseek(fd, phdr.p_offset, SEEK_SET);
        uint8_t *bytes = malloc(phdr.p_filesz);
        size_t n = read(fd, bytes, phdr.p_filesz);
        NSMutableData *data = [NSMutableData dataWithBytes:bytes length:phdr.p_filesz];
        free(bytes);
        if (n != phdr.p_filesz) {
            @throw [NSException exceptionWithName:@"ELF Error" reason:@"read failed" userInfo:nil];
        }
        [data setLength:phdr.p_memsz];
        */
        
        // remap virtual address to physical address for loading into flash -denis
        NSLog(@"program p_vaddr=0x%08lx p_paddr=0x%08lx", phdr.p_vaddr, phdr.p_paddr);
        NSNumber *key = [NSNumber numberWithLong:phdr.p_vaddr];
        FDExecutableSection *section = [sectionByAddress objectForKey:key];
        if (section) {
            [sectionByAddress removeObjectForKey:key];
            section.address = phdr.p_paddr;
            key = [NSNumber numberWithLong:section.address];
            [sectionByAddress setObject:section forKey:key];
        }
    }
    
    elf_end(e);
    close(fd);
    
    _sections = [sectionByAddress allValues];
}

- (void)load:(NSString *)filename
{
    const char* cfilename = [filename cStringUsingEncoding:NSASCIIStringEncoding];
    [self loadSymbols:cfilename];
    [self loadProgram:cfilename];
}

@end
