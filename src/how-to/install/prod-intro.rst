Introduction
=============

.. warning::

    It is *strongly recommended* to have followed and completed the demo installation :ref:`helm` before continuing with this page. The demo installation is simpler, and already makes you aware of a few things you need (TLS certs, DNS, a VM, ...).

A production installation consists of several parts:

Part 1 - you're on your own here, and need to create a set of VMs as detailed in :ref:`planning_prod`

Part 2 (:ref:`ansible_vms`) deals with installing components directly on a set of virtual machines, such as kubernetes itself, as well as databases. It makes use of ansible to achieve that.

Part 3 (:ref:`helm_prod`) is similar to the demo installation, and uses the tool ``helm`` to install software on top of kubernetes.

Part 4 (:ref:`configuration_options`) details other possible configuration options and settings to fit your needs.
