package com.myapp;

/**
 * Hello world!
 *
 */
public class App 
{
    public static void main( String[] args )
    {
        String version = args.length > 0 ? args[0] : "NoVersion";

        System.out.println( "Hello World!\nMy Name is Daniel Barel\nThis is version:" + version );
    }
}
