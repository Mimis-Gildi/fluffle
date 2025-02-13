#!/usr/bin/env zsh

test_io=true
test_cpu=false
test_mem=false

h1="========================================"
h2="----------------------------------------"
h3="........................................"

if [[ "$(id -u)" != "0" ]]; then
  echo "ERROR: This script must be run as root. Exiting."
  exit 1
fi

echo -e "=> Operating over Key locations for reports."
agent_host_name=$(hostname)
agent_work_dir=/var/actions
agent_test_dir="${agent_work_dir}/runner-tests"
bench_results_dir="${HOME}/bench"
bench_results_components_dir="${bench_results_dir}/components"
bench_summary_file="${bench_results_dir}/${agent_host_name}-summary.log"

echo -e "=> Designed to operate ONLY on the agent WORKING mount: ${agent_work_dir}."
if [[ ! -d "${agent_work_dir}" ]]; then
  echo "ERROR: Directory ${agent_work_dir} does not exist. Agent misconfigured. Exiting."
  exit 2
fi

echo -e "=> Tests are are preformed in a dedicated sibling directory: ${agent_test_dir}."
if [[ ! -d "${agent_test_dir}" ]]; then
  echo "Warning: Directory ${agent_test_dir} does not exist. Creating..."
  mkdir -p "${agent_test_dir}"
fi

echo -e "=> Results are stored in a dedicated directory: ${bench_results_dir}; with component subdirectory: ${bench_results_components_dir}."
if [[ ! -d "${bench_results_components_dir}" ]]; then
  echo "Warning: Directory ${bench_results_components_dir} does not exist. Creating..."
  mkdir -p "${bench_results_components_dir}"
fi

echo -e "=> Entering test directory: ${agent_test_dir}."
cd "${agent_test_dir}" || exit 11

echo -e "=> Setting agent-specific parallelism values."
typeset -i core_count load_count hyper_count file_count queue_count
core_count=$(grep processor /proc/cpuinfo -c )
(( hyper_count = core_count * 2 ))
(( load_count = core_count * 16 ))
(( file_count = 128 * 7 ))
(( queue_count = 128 + 64 ))
echo -e "=> Running tests with parallelism: ${core_count} cores, ${hyper_count} threads, ${load_count} threads, ${file_count} files, ${queue_count} queue size."

echo -e "(${agent_host_name}) Load Tests System Information:\n------------------------------------------------------------------------------" > "${bench_summary_file}"
date '+%F_%H:%M:%S' | tee -a "${bench_summary_file}"
echo -e "CPU Cores: ${core_count}" | tee -a "${bench_summary_file}"
echo -e "Memory:\n $(free -hvw)" | tee -a "${bench_summary_file}"
echo -e "\n\nRunning Tests:"

if ${test_io}; then
  echo -e "=> File IO Tests:"
  printf "%-42s%-42s%-42s%-42s\n" "${h1}" "File IO" "${h1}" "${h1}" | tee -a "${bench_summary_file}"

  for test_mode in rndrd rndwr rndrw; do
    for io_mode in sync async mmap; do
      component_file="${bench_results_components_dir}/IO-${test_mode}-${io_mode}.log"
      echo "=> ${test_mode}-${io_mode}"
      sysbench fileio --file-test-mode=${test_mode} --file-io-mode=${io_mode} --file-num=$file_count --file-total-size=4G --file-async-backlog=$queue_count --file-rw-ratio=1.1 prepare
      sysbench --threads="$core_count" fileio --file-test-mode=${test_mode} --file-io-mode=${io_mode} --file-num=$file_count --file-total-size=4G --file-async-backlog=$queue_count --file-rw-ratio=1.1 run | tee "${component_file}"
    done
  done

  printf "%-4s%-32s\n" "Test Mode" "Read mib/s " "write mib/s" "#r/s (sync)" "#r/s (async)" "#r/s (mmap)" "W/s" "FSync/s" "R Mib/s" "W Mib/s" "Average latency ms" | tee -a "${bench_summary_file}"
  printf "%-42s%-42s%-42s%-42s\n" "${h2}" "${h2}" "${h2}" "${h2}" | tee -a "${bench_summary_file}"
fi


#      reads_per_sec=$(grep "reads/s:" "${component_file}" | awk '{print $2}')
#      writes_per_sec=$(grep "writes/s:" "${component_file}" | awk '{print $2}')
#      fsyncs_per_sec=$(grep "fsyncs/s:" "${component_file}" | awk '{print $2}')
#      read_mibps=$(grep "read, MiB/s:" "${component_file}" | awk '{print $3}')
#      written_mibps=$(grep "written, MiB/s:" "${component_file}" | awk '{print $3}')
#      latency_avg=$(grep "avg:" "${component_file}" | awk '{print $2}')
#
#      if [[ "${test_mode}" == "rndrd" ]]; then
#        printf "%-22s %-10s %-10s %-8s %-8s %-8s %-10s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "Read" "${io_mode}" "${reads_per_sec}" "-" "${fsyncs_per_sec}" "${read_mibps}" "-" "${latency_avg}" | tee -a "${bench_summary_file}"
#      elif [[ "${test_mode}" == "rndwr" ]]; then
#        printf "%-22s %-10s %-10s %-8s %-8s %-8s %-10s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "Write" "${io_mode}" "-" "${writes_per_sec}" "${fsyncs_per_sec}" "-" "${written_mibps}" "${latency_avg}" | tee -a "${bench_summary_file}"
#      elif [[ "${test_mode}" == "rndrw" ]]; then
#        printf "%-22s %-10s %-10s %-8s %-8s %-8s %-10s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "Read/Write" "${io_mode}" "${reads_per_sec}" "${writes_per_sec}" "${fsyncs_per_sec}" "${read_mibps}" "${written_mibps}" "${latency_avg}" | tee -a "${bench_summary_file}"
#      else
#        echo "ERROR: Unknown test mode: ${test_mode}"
#      fi



if ${test_cpu}; then
  echo -e "=> CPU Load Tests:"
  printf "%-42s %-8s %12s %-42s\n" "${h1}" "on ${agent_host_name}" "CPU (${core_count} cores)" "${h1}" | tee -a "${bench_summary_file}"
  cpu_component_file="${bench_results_components_dir}/CPU.log"
  sysbench cpu --threads="$core_count" run | tee "${cpu_component_file}"
  threads=$(grep "Number of threads:" "${cpu_component_file}" | awk '{print $4}')
  events_per_sec=$(grep "events per second:" "${cpu_component_file}" | awk '{print $4}')
  latency_avg=$(grep "avg:" "${cpu_component_file}" | awk '{print $2}')
  printf "%-22s %-14s %-10s %-16s\n" "Time-CPU" "Threads" "Events/s" "Average latency ms" | tee -a "${bench_summary_file}"
  printf "%-22s %-14s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "${threads}" "${events_per_sec}" "${latency_avg}" | tee -a "${bench_summary_file}"

  printf "%-42s %-8s %12s %-42s\n" "${h2}" "on ${agent_host_name}" "CPU MT (${hyper_count} threads)" "${h2}" | tee -a "${bench_summary_file}"
  cpu_component_file_mt="${bench_results_components_dir}/CPU-MT.log"
  sysbench cpu --threads="$hyper_count" run | tee "${cpu_component_file_mt}"
  threads=$(grep "Number of threads:" "${cpu_component_file_mt}" | awk '{print $4}')
  events_per_sec=$(grep "events per second:" "${cpu_component_file_mt}" | awk '{print $4}')
  latency_avg=$(grep "avg:" "${cpu_component_file_mt}" | awk '{print $2}')
  printf "%-22s %-14s %-10s %-16s\n" "Time-CPU-MT" "Threads" "Events/s" "Average latency ms" | tee -a "${bench_summary_file}"
  printf "%-22s %-14s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "${threads}" "${events_per_sec}" "${latency_avg}" | tee -a "${bench_summary_file}"

  printf "%-42s %-8s %12s %-42s\n" "${h3}" "on ${agent_host_name}" "CPU LOAD (${load_count} threads)" "${h3}" | tee -a "${bench_summary_file}"
  cpu_component_file_load="${bench_results_components_dir}/CPU-LOAD.log"
  sysbench cpu --threads="$load_count" run | tee "${cpu_component_file_load}"
  threads=$(grep "Number of threads:" "${cpu_component_file_load}" | awk '{print $4}')
  events_per_sec=$(grep "events per second:" "${cpu_component_file_load}" | awk '{print $4}')
  latency_avg=$(grep "avg:" "${cpu_component_file_load}" | awk '{print $2}')
  printf "%-22s %-14s %-10s %-16s\n" "Time-CPU-LOAD" "Threads" "Events/s" "Average latency ms" | tee -a "${bench_summary_file}"
  printf "%-22s %-14s %-10s %-16s\n" "$(date '+%F_%H:%M:%S')" "${threads}" "${events_per_sec}" "${latency_avg}" | tee -a "${bench_summary_file}"
fi

if ${test_mem}; then
  echo -e "=> Memory Tests:"
  printf "%-42s %-8s %12s %-42s\n" "${h1}" "on ${agent_host_name}" "Memory" "${h1}" | tee -a "${bench_summary_file}"

  printf "%-22s %-10s %-14s %-16s %-12s %-18s\n" "Test Time" "Duration" "Threads" "Operation" "Throughput" "Latency" | tee -a "${bench_summary_file}"
  typeset -i gbs
  for scope in local global; do
    for threads in 1 4 64; do
      for size in 1K 4K 16K 4M; do
        for op in read write; do
          memory_component_file="${bench_results_components_dir}/MEM-${threads}-${op}-${scope}-${size}.log"
          sysbench memory --threads="$threads" --memory-block-size=${size} --memory-total-size=12G --memory-scope=${scope} --memory-oper=${op} run | tee "${memory_component_file}"
          threads_used=$(grep "Number of threads: " "${memory_component_file}" | awk '{print $4}')
          latency_avg=$(grep "avg:" "${memory_component_file}" | awk '{print $2}')
          throughput=$(grep -Eo '[0-9]+\.[0-9]+ MiB/sec' "${memory_component_file}" | awk '{print $1}')
          (( gbs = (throughput + 512) / 1024 ))
          duration=$(grep "total time:" "${memory_component_file}" | awk '{print $3}')
          echo "$h2$h2"
          printf "%-22s %-10s %-14s %-16s %12s %-18s\n" "$(date '+%F_%H:%M:%S')" "${duration}" "${threads}/${threads_used}" "${op}-${scope}-${size}" "${gbs}" "${latency_avg}" | tee -a "${bench_summary_file}"
          echo "$h3$h3"
        done
      done
    done
  done
fi

echo -e "\n------------------------------------------------------------------------------\n\n" >> "${bench_summary_file}"
cat "${bench_summary_file}"

