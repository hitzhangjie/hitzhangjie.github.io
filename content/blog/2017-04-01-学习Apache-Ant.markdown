---
layout: page 
title: 学习Apache Ant
color: blue 
width: 4
height: 1
date: 2017-04-01 17:45:40 +0800
tags: ["maven", "java"]
toc: true
---

Apache Ant是由Apache开发的基于Java的构建工具，本文对tutorialspoint上面的Apache Ant教程进行简要总结。

### 1 为什么需要这样一个构建工具？
Ant是Another Neat Tool的缩写形式，为什么需要这样一个工具呢？跟它的名字一样，就是希望我们开发人员的工作能够更加neat！

开发人员有些琐碎的、重复性的工作，包括：编译代码、打包可执行程序、部署程序到测试服务器、测试改变、拷贝代码到不同的地方。Ant可以帮助我们自动化上面列举的这几个步骤，简化我们的工作。

Ant是tomcat的作者开发出来的，最初适用于构建tomcat的，并且作为tomcat的一部分，之所以开发它是为了弥补当初Apache Make工具（没有在apache项目列表中搜索到该项目）的不足之处，2000年的时候Ant从tomcat项目中独立出来作为一个独立的项目开发。

至于Apache Ant的优势具体在哪，这个我们最后在给出来，目的是让大家结合自身工作经历，根据Apache Ant的功能自己主动去发现它的优势。

### 2 Ant build.xml
Ant的构建脚本默认是build.xml，也可以用其他的文件名。build.xml里面通常包括tag <project name="" default="" basedir=""/>，这里name指定了工程的名字，default是默认名字，basedir指定了工程的根目录。另外还包括多个tag <target name="" depends=""/>，其中name指定了目标动作的名字，例如compile、package、clean等等，它们之间存在某种依赖关系，可以通过depends指定。例如package依赖clean、compile，就可以指定depends="clean,package"，注意依赖先后顺序，不要写成depends="package,clean"。

示例1：

```java
<?xml version="1.0"?>
   <project name="Hello World Project" default="info">

   <target name="info">
      <echo>Hello World - Welcome to Apache Ant!</echo>
   </target>
</project>
```

示例2：

```java
<target name="deploy" depends="package">
  ....
</target>
<target name="package" depends="clean,compile">
  ....
</target>
<target name="clean" >
  ....
</target>
<target name="compile" >
  ....
</target>
```

build.xml里面可以使用ant预先定义的一些变量，例如：

|property|desc|
|:-------|:---|
|ant.file|The full location of the build file.|
|ant.version|The version of the Apache Ant installation.|
|basedir|The basedir of the build, as specified in the basedir attribute of the project element.|
|ant.java.version|The version of the JDK that is used by Ant.|
|ant.project.name|The name of the project, as specified in the name atrribute of the project element.|
|ant.project.default-target|The default target of the current project.|
|ant.project.invoked-targets|Comma separated list of the targets that were invoked in the current project.|
|ant.core.lib|The full location of the Ant jar file.|
|ant.home|The home directory of Ant installation.|
|ant.library.dir|The home directory for Ant library files - typically ANT_HOME/lib folder.|

示例1：

```java
<?xml version="1.0"?>
<project name="Hello World Project" default="info">
   <property name="sitename" value="www.tutorialspoint.com"/>
   <target name="info">
      <echo>Apache Ant version is ${ant.version} - You are at ${sitename} </echo>
   </target>
</project>
```

这样ant构建过程中会输出当前ant使用的版本以及站点名称，其中ant.version是ant的预定义变量，sitename是我们自己定义的变量。

### 3 Ant build.properties
像上线这样在build.xml里面创建自定义变量的方式，如果自定义变量少的话还可以，当面对一个大型的工程有很多自定义变量的时候，直接在build.xml里面定义变量就困难了，那怎么办呢？
我们可以在一个单独的属性配置文件中对需要用到的自定义属性进行配置，然后在build.xml里面进行引用。这个默认的属性配置文件是build.properties。

示例1：

build.xml：

```java
<?xml version="1.0"?>
<project name="Hello World Project" default="info">
   <property file="build.properties"/>
   
   <target name="info">
      <echo>Apache Ant version is ${ant.version} - You are at ${sitename} </echo>
   </target>
   
</project>
```
这个文件里面引用了一个自定义变量，我们将其定义在build.properties里面。

build.properties：

```java
# The Site Name
sitename=www.tutorialspoint.com
buildversion=3.3.2
```

### 4 Ant Data Types
不要将这里的数据类型跟编程语言中的数据类型混为一谈，这里说要描述的Ant提供的数据类型代表了Ant提供的一种service。

fileset类型代表了一系列文件集合，通过它可以包括某些文件或者排除某些文件，包括、排除文件是通过模式匹配的方式来实现。

示例1：

```java
<fileset dir="${src}" casesensitive="yes">
   <include name="**/*.java"/>
   <exclude name="**/*Stub*"/>
</fileset>
```
这个例子中创建了一个fileset，它指向了源代码目录${src}，这里匹配文件模式的时候大小写敏感，并且包括src目录下以及任意子目录下的java文件，并排除Stub文件。

patternset类型代表了一些列的pattern集合，通过它可以指定一些include用的pattern或者exclude用的pattern。这里我们队实例1进行一下改造，即示例2。

示例2：

```java
<patternset id="java.files.without.stubs">
   <include name="src/**/*.java"/>
   <exclude name="src/**/*Stub*"/>
</patternset>

<fileset dir="${src}" casesensitive="yes">
   <patternset refid="java.files.without.stubs"/>
</fileset>
```
通过patternset来指定pattern模式的方式有个好处，一个是更加直观，还有一个就是便于被复用。另外这里的pattern中可以使用的匹配符号包括：

|character|desc|
|:---|:---|
|?|可以匹配任意当个字符|
|\*|可以匹配0个或者多个字符|
|\*\*|可以匹配当前目录或者任意多级子目录（递归地哦）|

filelist类型与fileset有点类似但是又有不同。相同点是都是用于指定一个文件集合，不同点是fileset是通过pattern匹配的方式来完成包括、排除，而filelist是必须通过指定具体的文件名字，不能使用pattern进行匹配。

示例3：

```java
<filelist id="config.files" dir="${webapp.src.folder}">
   <file name="applicationConfig.xml"/>
   <file name="faces-config.xml"/>
   <file name="web.xml"/>
   <file name="portlet.xml"/>
</filelist>
```
上面这里定义了一个文件列表，包括了<file/>所指定的这些文件。

filterset类型往往用于筛选满足指定条件的文件，例如在copy任务中与fileset相结合拷贝指定版本的文件，看下这里的示例吧。

示例1：

```java
<copy todir="${output.dir}">
   <fileset dir="${releasenotes.dir}" includes="**/*.txt"/>
   <filterset>
      <filter token="VERSION" value="${current.version}"/>
   </filterset>
</copy>
```
上面这个动作是要fileset中指定的发行笔记文件拷贝到输出目录${output.dir}中，但是呢，这里拷贝的时候只拷贝特定版本的发行笔记，只有与filter中匹配的版本才会被拷贝。

path数据类型用于指定classpath，它有个好处就是可以对多个可能的classpath entries通过具体的系统指定的分隔符进行连接，例如在windows下面通过分号进行连接，但是在linux下面通过冒号进行连接。

示例1：

```java
<path id="build.classpath.jar">
   <pathelement path="${env.J2EE_HOME}/${j2ee.jar}"/>
   <fileset dir="lib">
      <include name="**/*.jar"/>
   </fileset>
</path>
```
上面这个示例就是将${J2EE_HOME}/${j2ee.jar}中的所有\*.jar都看做是一个classpath entry，然后用系统对应的classpath分隔符进行连接，最终构成一个完整的classpath。

### 5 Ant的一个简单构建示例
下面看一个Ant构建的完整示例，首先要创建一个工程，工程结构如下：

```java
+---db                // 数据库脚本目录
+---src               // 源代码目录
.  +---faxapp
.  +---dao
.  +---entity
.  +---util
.  +---web
+---war               // 资源目录
   +---images         // - 图片
   +---js             // - js
   +---META-INF       // - 其他
   +---styles         // - css文件
   +---WEB-INF
      +---classes     // - 编译输出classes文件
      +---jsp         // - 编写的jsp文件
      +---lib         // - 应用的jar包
```

对应的build.xml文件如下：

```java
<?xml version="1.0"?>
<project name="fax" basedir="." default="build">
   <property name="src.dir" value="src"/>
   <property name="web.dir" value="war"/>
   <property name="build.dir" value="${web.dir}/WEB-INF/classes"/>
   <property name="name" value="fax"/>
   <path id="master-classpath">
      <fileset dir="${web.dir}/WEB-INF/lib">
         <include name="*.jar"/>
      </fileset>
      <pathelement path="${build.dir}"/>
   </path>
   <target name="build" description="Compile source tree java files">
      <mkdir dir="${build.dir}"/>
      <javac destdir="${build.dir}" source="1.5" target="1.5">
         <src path="${src.dir}"/>
         <classpath refid="master-classpath"/>
      </javac>
   </target>
 
   <target name="clean" description="Clean output directories">
      <delete>
         <fileset dir="${build.dir}">
            <include name="**/*.class"/>
         </fileset>
      </delete>
   </target>
</project>
```

对于上面build.xml中用到的自定义属性，还需要创建对应的属性文件build.properties：

```java
<property name="src.dir" value="src"/>
<property name="web.dir" value="war"/>
<property name="build.dir" value="${web.dir}/WEB-INF/classes"/>
```

### 6 Ant构建文档
Ant可以为工程生成文档，这个是利用javadoc命令行工具来对某些包某些类某些访问类型修饰符对应的成员或者方法根据源代码中添加的javadoc注释来生成项目API文档。下面是一个示例。

示例1：

```java
<target name = "generate-javadoc">
   <javadoc packagenames="faxapp.*" sourcepath="${src.dir}" 
      destdir = "doc" version = "true" windowtitle = "Fax Application">
      
      <doctitle><![CDATA[= Fax Application =]]></doctitle>
      
      <bottom>
         <![CDATA[Copyright © 2011. All Rights Reserved.]]>
      </bottom>
      
      <group title = "util packages" packages = "faxapp.util.*"/>
      <group title = "web packages" packages = "faxapp.web.*"/>
      <group title = "data packages" packages = "faxapp.entity.*:faxapp.dao.*"/>
   </javadoc>
   
   <echo message = "java doc has been generated!" />
</target>
```

### 7 Ant构建jar包
Ant将classes达成jar包示例，例如将faxapp/util下面的除Test.class之外的所有文件达成一个jar包${web.dir}/lib/util.jar。

示例1：

```java
<jar destfile = "${web.dir}/lib/util.jar"
 basedir = "${build.dir}/classes"
 includes = "faxapp/util/**"
 excludes = "**/Test.class" />
```
如果是希望将util.jar打包成一个可以执行的jar文件的话，需要为其指定main-class，这里可以通过添加manifest来完成。

示例2：

```java
<jar destfile = "${web.dir}/lib/util.jar"
   basedir = "${build.dir}/classes"
   includes = "faxapp/util/**"
   excludes = "**/Test.class">
   
   <manifest>
      <attribute name = "Main-Class" value = "com.tutorialspoint.util.FaxUtil"/>
   </manifest>
   
</jar>
```

最后呢，将上述jar翻到一个target里面：

```java
<target name="build-jar">
   <jar destfile="${web.dir}/lib/util.jar"
      basedir="${build.dir}/classes"
      includes="faxapp/util/**"
      excludes="**/Test.class">
      <manifest>
         <attribute name="Main-Class" value="com.tutorialspoint.util.FaxUtil"/>
      </manifest>
   </jar>
</target>
```

### 8 Ant构建war包
除了上面提到的构建jar包之外，Ant也可以用来构建war包，我们这里只给出一个详细的war包构建配置文件，不再详细展开。

示例1：

```java
<target name="build-war">
   <war destfile="fax.war" webxml="${web.dir}/web.xml">
      <fileset dir="${web.dir}/WebContent">
         <include name="**/*.*"/>
      </fileset>
      
      <lib dir="thirdpartyjars">
         <exclude name="portlet.jar"/>
      </lib>
      
      <classes dir="${build.dir}/web"/>
   </war>
   
</target>
```

### 9 Ant的一个完整build.xml配置
这里给出了一个综合配置示例，对前面说描述的内容进行了一下综合。

```java
<?xml version = "1.0"?>
<project name = "fax" basedir = "." default = "usage">
   <property file = "build.properties"/>
   <property name = "src.dir" value = "src"/>
   <property name = "web.dir" value = "war"/>
   <property name = "javadoc.dir" value = "doc"/>
   <property name = "build.dir" value = "${web.dir}/WEB-INF/classes"/>
   <property name = "name" value = "fax"/>
   <path id = "master-classpath">
      <fileset dir = "${web.dir}/WEB-INF/lib">
         <include name = "*.jar"/>
      </fileset>
      <pathelement path = "${build.dir}"/>
   </path>
    
   <target name = "javadoc">
      <javadoc packagenames = "faxapp.*" sourcepath = "${src.dir}" 
         destdir = "doc" version = "true" windowtitle = "Fax Application">
         
         <doctitle><![CDATA[<h1> =  Fax Application  = </h1>]]>
         </doctitle>
         <bottom><![CDATA[Copyright © 2011. All Rights Reserved.]]>
         </bottom>
         <group title = "util packages" packages = "faxapp.util.*"/>
         <group title = "web packages" packages = "faxapp.web.*"/> 
         <group title = "data packages" packages = "faxapp.entity.*:faxapp.dao.*"/>
      </javadoc>
   </target>
   <target name = "usage">
      <echo message = ""/>
      <echo message = "${name} build file"/>
      <echo message = "-----------------------------------"/>
      <echo message = ""/>
      <echo message = "Available targets are:"/>
      <echo message = ""/>
      <echo message = "deploy    --> Deploy application as directory"/>
      <echo message = "deploywar --> Deploy application as a WAR file"/>
      <echo message = ""/>
   </target>
   <target name = "build" description = "Compile main source tree java files">
      <mkdir dir = "${build.dir}"/>
      
      <javac destdir = "${build.dir}" source = "1.5" target = "1.5" debug = "true"
         deprecation = "false" optimize = "false" failonerror = "true">
         
         <src path = "${src.dir}"/>
         <classpath refid = "master-classpath"/>
         
      </javac>
   </target>
   <target name = "deploy" depends = "build" description = "Deploy application">
      <copy todir = "${deploy.path}/${name}" preservelastmodified = "true">
         <fileset dir = "${web.dir}">
            <include name = "**/*.*"/>
         </fileset>
      </copy>
   </target>
   <target name = "deploywar" depends = "build" description = "Deploy application as a WAR file">
   
      <war destfile = "${name}.war" webxml = "${web.dir}/WEB-INF/web.xml">
         <fileset dir = "${web.dir}">
            <include name = "**/*.*"/>
         </fileset>
      </war>
      
      <copy todir = "${deploy.path}" preservelastmodified = "true">
         <fileset dir = ".">
            <include name = "*.war"/>
         </fileset>
      </copy>
      
   </target>
    
   <target name = "clean" description = "Clean output directories">
      <delete>
         <fileset dir = "${build.dir}">
            <include name = "**/*.class"/>
         </fileset>
      </delete>
   </target>
   
</project>
```

### 10 Ant的一个更完整配置示例
这里针对war包与tomcat的结合给出一个配置示例。

build.properties：

```java
# Ant properties for building the springapp
appserver.home=c:\\install\\apache-tomcat-7.0.19
# for Tomcat 5 use $appserver.home}/server/lib
# for Tomcat 6 use $appserver.home}/lib
appserver.lib=${appserver.home}/lib
deploy.path=${appserver.home}/webapps
tomcat.manager.url=http://www.tutorialspoint.com:8080/manager
tomcat.manager.username=tutorialspoint
tomcat.manager.password=secret
```
build.xml:

```java
<?xml version="1.0"?>
<project name="fax" basedir="." default="usage">
   <property file="build.properties"/>
   <property name="src.dir" value="src"/>
   <property name="web.dir" value="war"/>
   <property name="javadoc.dir" value="doc"/>
   <property name="build.dir" value="${web.dir}/WEB-INF/classes"/>
   <property name="name" value="fax"/>
   <path id="master-classpath">
      <fileset dir="${web.dir}/WEB-INF/lib">
         <include name="*.jar"/>
      </fileset>
   <pathelement path="${build.dir}"/>
   </path>
    
   <target name="javadoc">
      <javadoc packagenames="faxapp.*" sourcepath="${src.dir}" 
         destdir="doc" version="true" windowtitle="Fax Application">
         <doctitle><![CDATA[<h1>= Fax Application = </h1>]]></doctitle>
         <bottom><![CDATA[Copyright © 2011. All Rights Reserved.]]></bottom>
         <group title="util packages" packages="faxapp.util.*"/>
         <group title="web packages" packages="faxapp.web.*"/>
         <group title="data packages" packages="faxapp.entity.*:faxapp.dao.*"/>
      </javadoc>
   </target>
   <target name="usage">
   <echo message=""/>
   <echo message="${name} build file"/>
   <echo message="-----------------------------------"/>
   <echo message=""/>
   <echo message="Available targets are:"/>
   <echo message=""/>
   <echo message="deploy    --> Deploy application as directory"/>
   <echo message="deploywar --> Deploy application as a WAR file"/>
   <echo message=""/>
   </target>
   <target name="build" description="Compile main source tree java files">
   <mkdir dir="${build.dir}"/>
      <javac destdir="${build.dir}" source="1.5" target="1.5" debug="true"
         deprecation="false" optimize="false" failonerror="true">
         <src path="${src.dir}"/>
         <classpath refid="master-classpath"/>
      </javac>
   </target>
   <target name="deploy" depends="build" description="Deploy application">
      <copy todir="${deploy.path}/${name}" 
         preservelastmodified="true">
         <fileset dir="${web.dir}">
            <include name="**/*.*"/>
         </fileset>
      </copy>
   </target>
   <target name="deploywar" depends="build" description="Deploy application as a WAR file">
      <war destfile="${name}.war" webxml="${web.dir}/WEB-INF/web.xml">
         <fileset dir="${web.dir}">
            <include name="**/*.*"/>
         </fileset>
      </war>
      
      <copy todir="${deploy.path}" preservelastmodified="true">
         <fileset dir=".">
            <include name="*.war"/>
         </fileset>
      </copy>
   </target>
    
   <target name="clean" description="Clean output directories">
      <delete>
         <fileset dir="${build.dir}">
            <include name="**/*.class"/>
         </fileset>
      </delete>
   </target>
```

war包相关的定义已经全部给出了，这里还需要给出tomcat相关的部分定义，还是在build.xml里面。

```java
    <!-- ============================================================ -->
    <!-- Tomcat tasks -->
    <!-- ============================================================ -->
    <path id="catalina-ant-classpath">
        <!-- We need the Catalina jars for Tomcat -->
        <!--  * for other app servers - check the docs -->
        <fileset dir="${appserver.lib}">
            <include name="catalina-ant.jar"/>
        </fileset>
    </path>
    <taskdef name="install" classname="org.apache.catalina.ant.InstallTask">
        <classpath refid="catalina-ant-classpath"/>
    </taskdef>
    <taskdef name="reload" classname="org.apache.catalina.ant.ReloadTask">
        <classpath refid="catalina-ant-classpath"/>
    </taskdef>
    <taskdef name="list" classname="org.apache.catalina.ant.ListTask">
        <classpath refid="catalina-ant-classpath"/>
    </taskdef>
    <taskdef name="start" classname="org.apache.catalina.ant.StartTask">
        <classpath refid="catalina-ant-classpath"/>
    </taskdef>
    <taskdef name="stop" classname="org.apache.catalina.ant.StopTask">
        <classpath refid="catalina-ant-classpath"/>
    </taskdef>
    <target name="reload" description="Reload application in Tomcat">
        <reload url="${tomcat.manager.url}"username="${tomcat.manager.username}"
          password="${tomcat.manager.password}" path="/${name}"/>
    </target>
</project>
```

下面对tomcat相关的几个targe他进行一下描述：
| task | desc |
|:----:|:----:|
|InstallTask|Installs a web application. Class Name: org.apache.catalina.ant.InstallTask|
|ReloadTask|Reload a web application. Class Name: org.apache.catalina.ant.ReloadTask|
|ListTask|Lists all web applications. Class Name: org.apache.catalina.ant.ListTask|
|StartTask|Starts a web application. Class Name: org.apache.catalina.ant.StartTask|
|StopTask|Stops a web application. Class Name: org.apache.catalina.ant.StopTask|
|ReloadTask|Reloads a web application without stopping. Class Name: org.apache.catalina.ant.ReloadTask|

### 11 Ant执行程序
下面给出一个Ant传递参数并执行程序的配置示例。

java类：

```java
public class NotifyAdministrator
{
   public static void main(String[] args)
   {
      String email = args[0];
      notifyAdministratorviaEmail(email);
      System.out.println("Administrator "+email+" has been notified");
   }
   public static void notifyAdministratorviaEmail(String email
   { 
       //......
   }
}
```

build.xml配置文件如下：

```java
<?xml version="1.0"?>
<project name="sample" basedir="." default="notify">
   <target name="notify">
      <java fork="true" failonerror="yes" classname="NotifyAdministrator">
         <arg line="admin@test.com"/>
      </java>
   </target>
</project>
```

### 12 扩展Ant
Ant中有一些自定义的task，但是我们也可以自己定义task并在target中使用，下面是一个示例。

java代码：

```java
package com.tutorialspoint.ant;
import org.apache.tools.ant.Task;
import org.apache.tools.ant.Project;
import org.apache.tools.ant.BuildException;
public class MyTask extends Task {
   String message;
   public void execute() throws BuildException {
      log("Message: " + message, Project.MSG_INFO);
   }
   
   public void setMessage(String message) {
      this.message= message;
   }
}
```

build.xml：

```java
<target name="custom">
   <taskdef name="custom" classname="com.tutorialspoint.ant.MyTask" />
   <custom message="Hello World!"/>
</target>
```

### 13 在IDE中使用Ant
在IDE中使用Ant也是一种不错的选择，目前的主流开发工具Eclipse和Idea都继承了Ant构建插件，开发人员可以根据自己的情况选择使用。


参考内容：

[[1]] TutorialsPoint: Learn Apache Ant 

[1]: https://www.tutorialspoint.com/ant/index.htm
